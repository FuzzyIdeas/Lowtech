import Atomics
import Foundation
import os

private let logger = Logger(subsystem: lowtechLogSubsystem, category: "ProcessUtil")

// MARK: - ProcessStatus

public struct ProcessStatus {
    public var output: Data?
    public var error: Data?
    public var success: Bool
    public var process: Process?

    public var o: String? {
        output?.s?.trimmed
    }

    public var e: String? {
        error?.s?.trimmed
    }
}

public func stdout(of process: Process) -> Data? {
    let stdout = process.standardOutput as! FileHandle
    try? stdout.close()

    guard let path = process.environment?["__swift_stdout"],
          let stdoutFile = FileHandle(forReadingAtPath: path) else { return nil }
    if #available(macOS 10.15.4, *) {
        return try! stdoutFile.readToEnd()
    } else {
        return stdoutFile.readDataToEndOfFile()
    }
}

public func stderr(of process: Process) -> Data? {
    let stderr = process.standardError as? FileHandle
    try? stderr?.close()

    guard let path = process.environment?["__swift_stderr"],
          let stderrFile = FileHandle(forReadingAtPath: path) else { return nil }
    if #available(macOS 10.15.4, *) {
        return try! stderrFile.readToEnd()
    } else {
        return stderrFile.readDataToEndOfFile()
    }
}

@inline(__always) public var fm: FileManager {
    FileManager.default
}

public extension Process {
    var stdoutFilePath: String? {
        environment?["__swift_stdout"]
    }
    var stderrFilePath: String? {
        environment?["__swift_stderr"]
    }

    /// Delete the directory holding this process's stdout and stderr.
    ///
    /// Call it once the output has been read. `stdout(of:)` and `stderr(of:)`
    /// open those files by path, so a read after this returns nil rather than
    /// stale bytes. Only ever removes a directory inside this app's own base,
    /// so a hand-set `__swift_stdout` cannot aim it somewhere else.
    func cleanupOutputDir() {
        guard let base = processOutputBase, let path = stdoutFilePath else { return }
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        guard dir.deletingLastPathComponent().standardizedFileURL == base.standardizedFileURL else { return }
        try? fm.removeItem(at: dir)
    }
}

/// One directory per app process to hold child stdout and stderr, instead of a
/// fresh item-replacement directory per call.
///
/// `.itemReplacementDirectory` mints a new `NSIRD_*` folder every time it is
/// asked and nothing ever deleted them, so an app that shells out on a timer
/// left tens of thousands of directories behind: 30k folders and 148MB over a
/// week in one case, faster than the system reaper reclaims them.
///
/// The pid is in the name so a sweep can tell a dead app's leftovers from a live
/// sibling's working set.
private let processOutputBase: URL? = {
    let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lowtech-proc-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    do {
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
    } catch {
        logger.error("Could not create the process output directory: \(error)")
        return nil
    }
    sweepDeadProcessOutputDirs()
    return base
}()

/// Remove what previous runs of this app left behind. A directory is only
/// touched when no process holds its pid any more, so a second instance running
/// right now keeps its own.
private func sweepDeadProcessOutputDirs() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    guard let entries = try? fm.contentsOfDirectory(atPath: tmp.path) else { return }
    let mine = ProcessInfo.processInfo.processIdentifier
    for entry in entries where entry.hasPrefix("lowtech-proc-") {
        guard let pid = Int32(entry.dropFirst("lowtech-proc-".count)), pid != mine else { continue }
        // ESRCH means nothing owns that pid. EPERM means something does, and it
        // is not ours to clean up.
        guard kill(pid, 0) != 0, errno == ESRCH else { continue }
        try? fm.removeItem(at: tmp.appendingPathComponent(entry))
    }
}

/// Runs since the last sweep of our own directory. A caller that never reads a
/// process's output leaves its run directory behind, so the count triggers an
/// occasional pass rather than paying for one every time.
private let runsSinceSweep = ManagedAtomic<Int>(0)
private let sweepEveryRuns = 64
private let staleRunDirAge: TimeInterval = 600

private func sweepStaleRunDirs() {
    guard let base = processOutputBase,
          let entries = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let cutoff = Date().addingTimeInterval(-staleRunDirAge)
    for entry in entries {
        let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let modified, modified < cutoff else { continue }
        try? fm.removeItem(at: entry)
    }
}

public func shellProc(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    guard let outputDir = processOutputBase else {
        return nil
    }
    if runsSinceSweep.wrappingIncrementThenLoad(ordering: .relaxed) % sweepEveryRuns == 0 {
        sweepStaleRunDirs()
    }
    let binName = (launchPath.fileURL?.lastPathComponent ?? launchPath).safeFilename
    let argNames = args
        .map { arg in arg.contains("/") ? (arg.fileURL?.lastPathComponent ?? arg) : arg }
        .joined(separator: "_").safeFilename.prefix(250)
    let now = Date().timeIntervalSince1970.intround
    let procOutputDir = outputDir.appendingPathComponent("\(binName)(\(argNames))-\(now)".prefix(200).s)
    try? fm.createDirectory(at: procOutputDir, withIntermediateDirectories: true, attributes: nil)

    let stdoutFilePath = procOutputDir.appendingPathComponent("stdout").path
    fm.createFile(atPath: stdoutFilePath, contents: nil, attributes: nil)

    let stderrFilePath = procOutputDir.appendingPathComponent("stderr").path
    fm.createFile(atPath: stderrFilePath, contents: nil, attributes: nil)

    guard let stdoutFile = FileHandle(forWritingAtPath: stdoutFilePath),
          let stderrFile = FileHandle(forWritingAtPath: stderrFilePath)
    else {
        return nil
    }

    let task = Process()
    task.standardOutput = stdoutFile
    task.standardError = stderrFile
    task.launchPath = launchPath
    task.arguments = args

    var env = env ?? ProcessInfo.processInfo.environment
    env["__swift_stdout"] = stdoutFilePath
    env["__swift_stderr"] = stderrFilePath
    task.environment = env

    task.terminationHandler = { process in
        do {
            if let stdoutFile = process.standardOutput as? FileHandle {
                try stdoutFile.synchronize()
                try stdoutFile.close()
            }
            if let stderrFile = process.standardError as? FileHandle {
                try stderrFile.synchronize()
                try stderrFile.close()
            }
        } catch {
            logger.error("Error handling termination of process \(launchPath) \(args) [PID: \(process.processIdentifier)]: \(error)")
        }
    }

    do {
        try task.run()
    } catch {
        logger.error("Error running \(launchPath) \(args): \(error)")
        return nil
    }

    return task
}

public func shellProcDevNull(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    let task = Process()
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    task.launchPath = launchPath
    task.arguments = args

    task.environment = env ?? ProcessInfo.processInfo.environment

    do {
        try task.run()
    } catch {
        logger.error("Error running \(launchPath) \(args): \(error)")
        return nil
    }

    return task
}

public func shellProcOut(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = args

    task.environment = env ?? ProcessInfo.processInfo.environment

    do {
        try task.run()
    } catch {
        logger.error("Error running \(launchPath) \(args): \(error)")
        return nil
    }

    return task
}

public func shell(
    _ launchPath: String = "/bin/zsh",
    command: String,
    timeout: TimeInterval? = nil,
    env: [String: String]? = nil,
    wait: Bool = true
) -> ProcessStatus {
    shell(launchPath, args: ["-c", command], timeout: timeout, env: env, wait: wait)
}

public func shell(
    _ launchPath: String = "/bin/zsh",
    args: [String],
    timeout: TimeInterval? = nil,
    env: [String: String]? = nil,
    wait: Bool = true
) -> ProcessStatus {
    guard let task = shellProc(launchPath, args: args, env: env) else {
        return ProcessStatus(output: nil, error: nil, success: false)
    }

    guard wait else {
        return ProcessStatus(
            output: nil,
            error: nil,
            success: true,
            process: task
        )
    }

    guard let timeout else {
        task.waitUntilExit()
        let status = ProcessStatus(
            output: stdout(of: task),
            error: stderr(of: task),
            success: task.terminationStatus == 0,
            process: task
        )
        // The output is in hand, so the files behind it are dead weight. A
        // caller that shells out on a timer would otherwise leave one directory
        // per run behind for the rest of the app's life.
        task.cleanupOutputDir()
        return status
    }

    let waiter = asyncNow {
        task.waitUntilExit()
    }
    if waiter.wait(for: timeout) == .timedOut {
        // terminate() delivers SIGTERM asynchronously, and NSTask throws an ObjC
        // exception if terminationStatus is read before the process actually exits.
        // Wait for the exit, escalating to SIGKILL if SIGTERM is ignored.
        task.terminate()
        if waiter.wait(for: 2) == .timedOut, task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            _ = waiter.wait(for: 1)
        }
    }

    let status = ProcessStatus(
        output: stdout(of: task),
        error: stderr(of: task),
        success: !task.isRunning && task.terminationStatus == 0,
        process: task
    )
    task.cleanupOutputDir()
    return status
}
