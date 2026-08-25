import Foundation

// MARK: - ProcessStatus

public struct ProcessStatus {
    public var output: Data?
    public var error: Data?
    public var success: Bool

    public var o: String? {
        output?.s?.trimmed
    }

    public var e: String? {
        error?.s?.trimmed
    }
}

/// Read what the process wrote to stdout.
///
/// Reads by path and never touches the write-side `FileHandle`. Closing it here
/// raced the termination handler doing the same on Foundation's own queue, and
/// was never needed: the child writes through its own descriptor and everything
/// it wrote is in the file by the time it exits.
public func stdout(of process: Process) -> Data? {
    readOutputFile(process.environment?["__swift_stdout"])
}

public func stderr(of process: Process) -> Data? {
    // This used to close `standardOutput` before reading the stderr file, so
    // stdout was closed twice and stderr's handle was never closed at all.
    readOutputFile(process.environment?["__swift_stderr"])
}

private func readOutputFile(_ path: String?) -> Data? {
    guard let path, let file = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? file.close() }

    do {
        return try file.readToEnd() ?? Data()
    } catch {
        err("Could not read \(path): \(error)")
        return nil
    }
}

@inline(__always) public var fm: FileManager {
    FileManager.default
}

/// One directory per app run to hold child stdout and stderr.
///
/// `.itemReplacementDirectory` mints a new `NSIRD_*` folder every time it is
/// asked and nothing ever deleted them, so shelling out on a timer left tens of
/// thousands of directories behind, faster than the system reaper reclaims them.
/// It was also created with `try!`, so a failure took the app down.
private let processOutputBase: URL? = {
    let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("lowtech-proc-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    do {
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
    } catch {
        err("Could not create the process output directory: \(error)")
        return nil
    }
    return base
}()

public extension Process {
    /// Delete the directory holding this process's stdout and stderr, once the
    /// output has been read. Only ever removes a directory inside our own base,
    /// so a hand-set `__swift_stdout` cannot aim it somewhere else.
    func cleanupOutputDir() {
        guard let base = processOutputBase, let path = environment?["__swift_stdout"] else { return }
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        guard dir.deletingLastPathComponent().standardizedFileURL == base.standardizedFileURL else { return }
        try? fm.removeItem(at: dir)
    }
}

public func shellProc(
    _ launchPath: String = "/bin/zsh",
    args: [String],
    env: [String: String]? = nil,
    onTermination: ((Process) -> Void)? = nil
) -> Process? {
    guard let base = processOutputBase else { return nil }

    // The UUID keeps two commands launched in the same second from sharing a
    // directory and truncating each other's stdout.
    let outputDir = base.appendingPathComponent("\(Date().timeIntervalSince1970.intround)-\(UUID().uuidString.prefix(8))", isDirectory: true)
    do {
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
    } catch {
        err("Could not create the output directory for \(launchPath) \(args): \(error)")
        return nil
    }

    let stdoutFilePath = outputDir.appendingPathComponent("stdout").path
    fm.createFile(atPath: stdoutFilePath, contents: nil, attributes: nil)

    let stderrFilePath = outputDir.appendingPathComponent("stderr").path
    fm.createFile(atPath: stderrFilePath, contents: nil, attributes: nil)

    // Opened up front so the one that did open can be closed when the other
    // didn't. The guard used to drop it and leak the descriptor.
    let openedStdout = FileHandle(forWritingAtPath: stdoutFilePath)
    let openedStderr = FileHandle(forWritingAtPath: stderrFilePath)
    guard let stdoutFile = openedStdout, let stderrFile = openedStderr else {
        err("Could not open the output files for \(launchPath) \(args)")
        try? openedStdout?.close()
        try? openedStderr?.close()
        try? fm.removeItem(at: outputDir)
        return nil
    }

    var launched = false
    defer {
        if !launched {
            try? stdoutFile.close()
            try? stderrFile.close()
            try? fm.removeItem(at: outputDir)
        }
    }

    let task = Process()
    task.standardOutput = stdoutFile
    task.standardError = stderrFile
    // Without this the child inherits our stdin and anything that decides to
    // prompt blocks forever on a descriptor nobody will ever write to.
    task.standardInput = FileHandle.nullDevice
    task.executableURL = URL(fileURLWithPath: launchPath)
    task.arguments = args

    var env = env ?? ProcessInfo.processInfo.environment
    env["__swift_stdout"] = stdoutFilePath
    env["__swift_stderr"] = stderrFilePath
    task.environment = env

    task.terminationHandler = { process in
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
        err("Error running \(launchPath) \(args): \(error)")
        return nil
    }
    launched = true

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

    // `success` here only says the process launched, and the caller owns
    // `cleanupOutputDir()`.
    guard wait else {
        return ProcessStatus(
            output: nil,
            error: nil,
            success: true
        )
    }

    guard let timeout else {
        task.waitUntilExit()
        let status = ProcessStatus(
            output: stdout(of: task),
            error: stderr(of: task),
            success: task.terminationStatus == 0
        )
        task.cleanupOutputDir()
        return status
    }

    // The wait rides on the termination handler rather than a thread parked in
    // `waitUntilExit()`, which a cancelled work item never leaves.
    if exited.wait(timeout: .now() + timeout) == .timedOut {
        // terminate() delivers SIGTERM asynchronously, and NSTask raises an
        // ObjC exception if terminationStatus is read before the process
        // actually exits. This used to terminate and read the status straight
        // away. Wait for the exit, escalating to SIGKILL if SIGTERM is ignored.
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
        success: !running && task.terminationStatus == 0
    )
    // A process that survived SIGKILL is still writing into that directory.
    if !running {
        task.cleanupOutputDir()
    }
    return status
}
