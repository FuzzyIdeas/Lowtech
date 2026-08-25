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

/// Read what the process wrote to stdout.
///
/// Returns nil only when there is nothing to read from: no path on the process,
/// the file is gone, or the read failed. An empty `Data` means the process ran
/// and printed nothing.
public func stdout(of process: Process) -> Data? {
    readOutputFile(process.stdoutFilePath)
}

public func stderr(of process: Process) -> Data? {
    readOutputFile(process.stderrFilePath)
}

/// Reads by path, and never touches the write-side `FileHandle`.
///
/// This used to close `process.standardOutput` first, which raced the
/// termination handler doing the same thing on Foundation's own queue:
/// `waitUntilExit()` returns the moment the child is reaped, so both closes ran
/// at once on a handle that is not thread-safe. Closing here was never needed
/// anyway, since the child writes through its own descriptor and everything it
/// wrote is in the file by the time it exits.
private func readOutputFile(_ path: String?) -> Data? {
    guard let path, let file = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? file.close() }

    do {
        return try file.readToEnd() ?? Data()
    } catch {
        logger.error("Could not read \(path): \(error)")
        return nil
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
        runDirs.unregister(dir.lastPathComponent)
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
    // Enumerating and deleting the whole of TMPDIR is not something to do on
    // whatever thread happened to shell out first, which is usually the main one.
    asyncNow { sweepDeadProcessOutputDirs() }
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

// MARK: - RunDirRegistry

/// The run directories that still belong to a process which hasn't exited.
///
/// A directory's mtime stops moving the moment it is created (writing to a file
/// inside it doesn't touch the parent), so age alone would have the stale sweep
/// delete the output of anything running longer than `staleRunDirAge`: a long
/// ffmpeg pass, or any `wait: false` caller. The child keeps writing into an
/// unlinked inode and the read afterwards comes back empty.
private final class RunDirRegistry {
    func register(_ name: String, for process: Process) {
        lock.lock()
        defer { lock.unlock() }
        entries[name] = process
    }

    func unregister(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: name)
    }

    /// Names of the directories whose process is still running. Drops the
    /// entries that have exited on the way through, so the map can't grow
    /// without bound when a caller never reads a process's output.
    func liveNames() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        entries = entries.filter(\.value.isRunning)
        return Set(entries.keys)
    }

    private let lock = NSLock()
    private var entries: [String: Process] = [:]

}

private let runDirs = RunDirRegistry()

/// Runs since the last sweep of our own directory. A caller that never reads a
/// process's output leaves its run directory behind, so the count triggers an
/// occasional pass rather than paying for one every time.
private let runCounter = ManagedAtomic<UInt64>(0)
private let sweepEveryRuns: UInt64 = 64
private let staleRunDirAge: TimeInterval = 600

private func sweepStaleRunDirs() {
    guard let base = processOutputBase,
          let entries = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let live = runDirs.liveNames()
    let cutoff = Date().addingTimeInterval(-staleRunDirAge)
    for entry in entries where !live.contains(entry.lastPathComponent) {
        let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let modified, modified < cutoff else { continue }
        try? fm.removeItem(at: entry)
    }
}

private extension String {
    /// Clamp to `maxBytes` UTF-8 bytes, keeping a readable head and appending a
    /// digest of the whole thing.
    ///
    /// A path component can't exceed 255 bytes. Truncating by character count
    /// used to be enough for ASCII and silently wrong for anything else: 200
    /// CJK characters is 600 bytes, `createDirectory` fails, the output handles
    /// come back nil and the entire command never runs. The digest also keeps
    /// two long command lines that share a prefix from landing on one directory.
    func clampedToBytes(_ maxBytes: Int) -> String {
        guard utf8.count > maxBytes else { return self }

        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        let digest = "-\(String(hash, radix: 36))"

        let budget = maxBytes - digest.utf8.count
        guard budget > 0 else { return digest }

        var head = ""
        var used = 0
        for character in self {
            let size = String(character).utf8.count
            guard used + size <= budget else { break }
            head.append(character)
            used += size
        }
        return head + digest
    }
}

/// Launch a process with its stdout and stderr going to files that
/// `stdout(of:)` and `stderr(of:)` can read back.
///
/// - Parameter env: replaces the child's environment wholesale rather than
///   merging into the current one, so a caller that passes `["PATH": …]` gives
///   the child that and nothing else. Pass
///   `ProcessInfo.processInfo.environment.merging(…)` to add to it instead.
/// - Parameter onTermination: runs after the output handles are closed, on
///   Foundation's termination queue.
public func shellProc(
    _ launchPath: String = "/bin/zsh",
    args: [String],
    env: [String: String]? = nil,
    onTermination: ((Process) -> Void)? = nil
) -> Process? {
    guard let outputDir = processOutputBase else {
        return nil
    }
    let run = runCounter.wrappingIncrementThenLoad(ordering: .relaxed)
    if run % sweepEveryRuns == 0 {
        asyncNow { sweepStaleRunDirs() }
    }

    let binName = (launchPath.fileURL?.lastPathComponent ?? launchPath).safeFilename
    let argNames = args
        .map { arg in arg.contains("/") ? (arg.fileURL?.lastPathComponent ?? arg) : arg }
        .joined(separator: "_").safeFilename
    let now = Date().timeIntervalSince1970.intround
    // The run number disambiguates two identical command lines started inside
    // the same second, which used to share a directory: the second launch
    // truncated the first's stdout, both children wrote into one file, and
    // whichever finished first deleted the directory out from under the other.
    let suffix = "-\(now)-\(run)"
    let dirName = "\(binName)(\(argNames))".clampedToBytes(240 - suffix.utf8.count) + suffix
    let procOutputDir = outputDir.appendingPathComponent(dirName)

    do {
        try fm.createDirectory(at: procOutputDir, withIntermediateDirectories: true, attributes: nil)
    } catch {
        logger.error("Could not create the output directory for \(launchPath) \(args): \(error)")
        return nil
    }

    let stdoutFilePath = procOutputDir.appendingPathComponent("stdout").path
    fm.createFile(atPath: stdoutFilePath, contents: nil, attributes: nil)

    let stderrFilePath = procOutputDir.appendingPathComponent("stderr").path
    fm.createFile(atPath: stderrFilePath, contents: nil, attributes: nil)

    // Opened up front rather than inside the guard, so the one that did open
    // can be closed when the other didn't. The guard used to drop it on the
    // floor and leak the descriptor.
    let openedStdout = FileHandle(forWritingAtPath: stdoutFilePath)
    let openedStderr = FileHandle(forWritingAtPath: stderrFilePath)
    guard let stdoutFile = openedStdout, let stderrFile = openedStderr else {
        logger.error("Could not open the output files for \(launchPath) \(args)")
        try? openedStdout?.close()
        try? openedStderr?.close()
        try? fm.removeItem(at: procOutputDir)
        return nil
    }

    // Every early return past this point has to close both handles and drop the
    // directory, or a failed launch leaks two descriptors and a folder.
    var launched = false
    defer {
        if !launched {
            try? stdoutFile.close()
            try? stderrFile.close()
            try? fm.removeItem(at: procOutputDir)
        }
    }

    let task = Process()
    task.standardOutput = stdoutFile
    task.standardError = stderrFile
    // Without this the child inherits our stdin and anything that decides to
    // prompt (ffmpeg asking to overwrite, say) blocks forever on a descriptor
    // nobody will ever write to, taking `waitUntilExit()` down with it.
    task.standardInput = FileHandle.nullDevice
    task.executableURL = URL(fileURLWithPath: launchPath)
    task.arguments = args

    var env = env ?? ProcessInfo.processInfo.environment
    env["__swift_stdout"] = stdoutFilePath
    env["__swift_stderr"] = stderrFilePath
    task.environment = env

    task.terminationHandler = { process in
        // Each close is separate: a failure on the first used to skip the
        // second and leak that descriptor. Nothing is synchronized here because
        // the parent never writes through these handles, the child has its own.
        if let stdoutFile = process.standardOutput as? FileHandle {
            try? stdoutFile.close()
        }
        if let stderrFile = process.standardError as? FileHandle {
            try? stderrFile.close()
        }
        onTermination?(process)
    }

    do {
        try task.run()
    } catch {
        logger.error("Error running \(launchPath) \(args): \(error)")
        return nil
    }
    launched = true
    runDirs.register(dirName, for: task)

    return task
}

public func shellProcDevNull(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    let task = Process()
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    task.standardInput = FileHandle.nullDevice
    task.executableURL = URL(fileURLWithPath: launchPath)
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

/// Launch a process that inherits our stdout and stderr.
///
/// Nothing is captured, so `stdout(of:)` and `stderr(of:)` return nil for the
/// returned process. Use `shellProc` when the output is wanted.
public func shellProcOut(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    let task = Process()
    task.standardInput = FileHandle.nullDevice
    task.executableURL = URL(fileURLWithPath: launchPath)
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
    let exited = DispatchSemaphore(value: 0)
    guard let task = shellProc(launchPath, args: args, env: env, onTermination: { _ in exited.signal() }) else {
        return ProcessStatus(output: nil, error: nil, success: false)
    }

    // `success` here only says the process launched. Nothing has run yet, and
    // the caller owns `cleanupOutputDir()`.
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

    // The wait rides on the termination handler rather than a thread parked in
    // `waitUntilExit()`. That thread came off the global queue and a cancelled
    // DispatchWorkItem never leaves `waitUntilExit()`, so every timed-out call
    // held a pool thread until the child died, and a handful of them at once
    // could starve libdispatch.
    if exited.wait(timeout: .now() + timeout) == .timedOut {
        // terminate() delivers SIGTERM asynchronously, and NSTask throws an ObjC
        // exception if terminationStatus is read before the process actually exits.
        // Wait for the exit, escalating to SIGKILL if SIGTERM is ignored.
        task.terminate()
        if exited.wait(timeout: .now() + 2) == .timedOut, task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            _ = exited.wait(timeout: .now() + 1)
        }
    }

    let running = task.isRunning
    let status = ProcessStatus(
        output: stdout(of: task),
        error: stderr(of: task),
        success: !running && task.terminationStatus == 0,
        process: task
    )
    // A process that survived SIGKILL (stuck in the kernel) is still writing
    // into that directory. Deleting it would leave it writing to an unlinked
    // inode, so leave it for the stale sweep once the process is gone.
    if !running {
        task.cleanupOutputDir()
    }
    return status
}
