import Cocoa
import Defaults
import Foundation
import os

private let logger = Logger(subsystem: lowtechLogSubsystem, category: "AppHangDetection")

// MARK: - RepeatingHang

/// A signature for a recurring hang. When a sampled main-thread stack contains
/// `expectedStackFrame`, the hang is attributed to `cause` and recorded in a
/// shared timestamp file used to detect repeating offenders.
public final class RepeatingHang {
    public init(cause: String, expectedStackFrame: String) {
        self.cause = cause
        self.expectedStackFrame = expectedStackFrame
    }

    public let cause: String
    public let expectedStackFrame: String

    public lazy var exceedsThreshold: Bool = {
        let exceeds = appHangStateQueue.sync {
            if count >= RepeatingHangStore.threshold {
                logger.warning("Detected repeating hangs due to \(self.cause) (\(self.count) in last \(RepeatingHangStore.window) seconds)")
                return true
            }
            return false
        }
        if exceeds {
            clearTimestamps()
        }
        return exceeds
    }()

    public lazy var count: Int = RepeatingHangStore.count(cause: cause, now: Date().timeIntervalSince1970)

    public func isCulprit(sampleOutput: String) -> Bool {
        guard sampleOutput.contains(expectedStackFrame) else { return false }
        logger.warning("Hang detected with expected stack frame '\(self.expectedStackFrame)' in sample output")
        return true
    }

    public func clearTimestamps() {
        appHangStateQueue.sync {
            var all = RepeatingHangStore.loadTimestamps()
            all[cause] = []
            RepeatingHangStore.saveTimestamps(all)
        }
    }
}

// MARK: - RepeatingHangStore

/// Persistent counter of recent hang occurrences, scoped per app via the bundle
/// identifier so multiple Lowtech apps don't share the same JSON file.
public enum RepeatingHangStore {
    public static let window: TimeInterval = 5 * 60
    public static let threshold = 3

    public static func record(cause: String, at timestamp: TimeInterval) {
        var all = loadTimestamps()
        var timestamps = all[cause, default: []]
        timestamps.append(timestamp)
        timestamps.removeAll { timestamp - $0 > window }
        all[cause] = timestamps
        saveTimestamps(all)
    }

    public static func count(cause: String, now: TimeInterval) -> Int {
        let timestamps = loadTimestamps()[cause, default: []]
        return timestamps.filter { now - $0 <= window }.count
    }

    static var fileName: String {
        let bundle = Bundle.main.bundleIdentifier ?? "com.lowtechguys.app"
        return "\(bundle).hang_causes.json"
    }

    static func fileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    static func loadTimestamps() -> [String: [TimeInterval]] {
        guard let data = try? Data(contentsOf: fileURL()) else { return [:] }
        return (try? JSONDecoder().decode([String: [TimeInterval]].self, from: data)) ?? [:]
    }

    static func saveTimestamps(_ timestamps: [String: [TimeInterval]]) {
        guard let data = try? JSONEncoder().encode(timestamps) else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

}

// MARK: - AppHangAction

/// Decision returned by an app-supplied hang handler to override the default
/// auto-restart behavior.
public enum AppHangAction {
    /// Do not auto-restart this time (e.g. a long-running CLI request is
    /// in-flight). The detector resets so subsequent hangs can re-trigger.
    case suppressRestart
    /// Apply the default behavior: restart when `Defaults[.autoRestartOnHang]`
    /// is enabled.
    case useDefault
}

// MARK: - State

private let appHangStateQueue = DispatchQueue(label: "com.lowtechguys.appHangDetection.state.\(Bundle.main.bundleIdentifier ?? "default")")
@MainActor private var appHangTimer: DispatchSourceTimer?
private var lastMainThreadCheckin: TimeInterval = 0
private var appHangTriggered = false
private var sleeping = false

private var registeredHangCauses: [String: RepeatingHang] = [:]
private var registeredHangHandler: ((String, String) -> AppHangAction)?
private var detectionIntervalSeconds: TimeInterval = 40.0

// MARK: - Public API

/// Installs a periodic main-thread liveness probe and triggers an auto-restart
/// (subject to `Defaults[.autoRestartOnHang]`) when the main thread misses
/// check-ins for longer than `detectionInterval` seconds. No-op in DEBUG.
///
/// - Parameters:
///   - detectionInterval: How long the main thread must be unresponsive before
///     a hang is reported. Default 40s.
///   - checkInterval: How often the background timer checks the last
///     check-in timestamp. Default 1s.
///   - repeatingHangs: Optional registry of known hang signatures. When a
///     detected hang's main-thread sample matches an entry's
///     `expectedStackFrame`, the occurrence is recorded in a per-app JSON
///     file so callers can spot repeating offenders.
///   - onHang: Optional main-actor callback invoked when a hang is detected.
///     Receives the full `sample(1)` output and the extracted main-thread
///     stack. Return `.suppressRestart` to skip the default auto-restart for
///     this occurrence (the detector resets so future hangs can re-trigger).
@MainActor public func configureAppHangDetection(
    detectionInterval: TimeInterval = 40.0,
    checkInterval: TimeInterval = 1.0,
    repeatingHangs: [String: RepeatingHang] = [:],
    onHang: ((_ sampleOutput: String, _ mainThreadStack: String) -> AppHangAction)? = nil
) {
    #if !DEBUG
        guard appHangTimer == nil else { return }

        detectionIntervalSeconds = detectionInterval
        registeredHangCauses = repeatingHangs
        registeredHangHandler = onHang

        appHangStateQueue.sync {
            lastMainThreadCheckin = Date().timeIntervalSince1970
            appHangTriggered = false
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(
            deadline: .now() + checkInterval,
            repeating: checkInterval,
            leeway: .milliseconds(250)
        )
        timer.setEventHandler {
            let now = Date().timeIntervalSince1970
            var shouldTrigger = false

            appHangStateQueue.sync {
                if !appHangTriggered, !sleeping, now - lastMainThreadCheckin > detectionIntervalSeconds {
                    appHangTriggered = true
                    shouldTrigger = true
                }
            }

            if shouldTrigger {
                onAppHangDetected()
            }

            DispatchQueue.main.async {
                appHangStateQueue.async {
                    lastMainThreadCheckin = Date().timeIntervalSince1970
                }
            }
            // Modal panels and event-tracking runloop modes (e.g. menu open, drag
            // in progress) don't drain DispatchQueue.main, so check in there too.
            RunLoop.main.perform(inModes: [.modalPanel, .eventTracking, .default, .common]) {
                appHangStateQueue.async {
                    lastMainThreadCheckin = Date().timeIntervalSince1970
                }
            }
        }
        appHangTimer = timer
        timer.resume()

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
            appHangStateQueue.sync {
                lastMainThreadCheckin = Date().timeIntervalSince1970
                sleeping = true
                appHangTriggered = false
            }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            let now = Date().timeIntervalSince1970
            appHangStateQueue.sync {
                lastMainThreadCheckin = now
                sleeping = false
                appHangTriggered = false
            }
        }
    #endif
}

// MARK: - Internals

private func mainThreadStack(from sampleOutput: String) -> String {
    let lines = sampleOutput.split(separator: "\n", omittingEmptySubsequences: false)
    var result: [Substring] = []
    var inMainThread = false

    for line in lines {
        if line.contains("Thread_") {
            if inMainThread { break }
            if line.contains("com.apple.main-thread") {
                inMainThread = true
            }
        }
        if inMainThread {
            result.append(line)
        }
    }

    return result.joined(separator: "\n")
}

private func onAppHangDetected() {
    logger.warning("App Hanging!")

    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleOutput = shell("/usr/bin/sample", args: ["\(pid)", "0.001"], timeout: 30).o ?? ""
    let mainThread = mainThreadStack(from: sampleOutput)
    logger.warning("Main thread sample:\n\(mainThread)")

    let action = registeredHangHandler?(sampleOutput, mainThread) ?? .useDefault
    if case .suppressRestart = action {
        logger.warning("Skipping auto-restart due to hang handler decision.")
        appHangStateQueue.sync { appHangTriggered = false }
        return
    }

    if Defaults[.autoRestartOnHang] {
        let now = Date().timeIntervalSince1970
        appHangStateQueue.async {
            if let hang = registeredHangCauses.values.first(where: { $0.isCulprit(sampleOutput: mainThread) }) {
                RepeatingHangStore.record(cause: hang.cause, at: now)
            }
        }
        logger.warning("Auto-restarting app due to hang detection.")
        asyncAfter(ms: 5000) { restart() }
    }
}
