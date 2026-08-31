import AppKit
import Combine
import Defaults
import Lowtech
import Sentry
import SwiftUI

public extension Defaults.Keys {
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let lastLaunchVersion = Key<String>("lastLaunchVersion", default: "")
    static let autoRestartOnHang = Key<Bool>("autoRestartOnHang", default: true)
    /// Stable, anonymous identifier persisted across launches so a user can be
    /// matched to their error reports in Sentry. See `LowtechSentry.sentryUserID`.
    static let sentryUserID = Key<String>("sentryUserID", default: "")
}

extension SentryStacktrace? {
    /// The main thread is parked in a modal loop or a deliberate wait, so the app is waiting on a
    /// person, not stuck. macOS keeps the runloop in `runModal` for as long as an alert or a panel
    /// stays on screen, which trips the 30s app-hang threshold every time someone walks away from a
    /// dialog. Reporting those buries the real hangs.
    var isWaitingForUser: Bool {
        guard let stack = self else {
            return false
        }
        return stack.frames.contains { frame in
            guard let function = frame.function else { return false }
            return function.contains("runModal") || function.contains("forTimeInterval")
        }
    }

    var isExpectedToHang: Bool {
        self == nil || isWaitingForUser
    }
}

public enum LowtechSentry {
    public static var enableSentry: Bool = Defaults[.enableSentry]
    public static var sentryDSN: String?

    public static func configureSentry(restartOnHang: Bool = true, getUser: @escaping () -> User) {
        guard let dsn = sentryDSN else { return }
        enableSentryObserver = enableSentryObserver ?? pub(.enableSentry)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { change in
                enableSentry = change.newValue
                if change.newValue {
                    configureSentry(getUser: getUser)
                } else {
                    SentrySDK.close()
                }
            }

        guard enableSentry else { return }
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

        let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"

        SentrySDK.start { options in
            options.enableCaptureFailedRequests = false
            options.dsn = dsn
            options.releaseName = "v\(release)"
            options.dist = release
            #if DEBUG
                options.appHangTimeoutInterval = 3
                // Debug builds must never upload crashes to the server: rely on the local `.ips`
                // (the re-raise in restartFromCrash lets ReportCrash write it). Disabling the crash
                // handler also keeps SentryCrash from installing signal handlers, so the app's own
                // fault traps stay the only ones in play.
                options.enableCrashHandler = false
            #else
                options.appHangTimeoutInterval = 30
            #endif
            options.swiftAsyncStacktraces = true
            #if os(macOS)
                // `NSApplicationCrashOnExceptions` turns an uncaught NSException into a SIGTRAP,
                // and without this the event carries only `_crashOnException` frames: no exception
                // name, no reason, nothing to act on (CLING-A).
                options.enableUncaughtNSExceptionReporting = true
            #endif
            options.beforeSend = { event in
                guard let exc = event.exceptions?.first, let mech = exc.mechanism, mech.type == "AppHang" else {
                    return event
                }
                guard !exc.stacktrace.isWaitingForUser else {
                    return nil
                }
                if restartOnHang, Defaults[.autoRestartOnHang], exc.stacktrace.isExpectedToHang {
                    asyncAfter(ms: 5000) { restart() }
                    if event.tags == nil {
                        event.tags = ["restarted": "true"]
                    } else {
                        event.tags!["restarted"] = "true"
                    }
                }
                return event
            }
        }

        SentrySDK.configureScope { scope in
            scope.setUser(getUser())
        }

        guard sentryLaunchEvent == nil, Defaults[.lastLaunchVersion] != release else { return }
        sentryLaunchEvent = mainAsyncAfter(ms: 5000) {
            guard enableSentry else { return }

            SentrySDK.capture(message: "Launch")
            Defaults[.lastLaunchVersion] = release
        }
    }

    public static func getSentryUser() -> User {
        User(userId: sentryUserID)
    }

    /// A stable, anonymous identifier for this install, persisted across launches.
    ///
    /// Seeded once from the machine serial number hash (falling back to a generated
    /// id when the serial can't be read) and then kept in `Defaults` so it never
    /// changes. Surfaced to users via `SentryUserIDPill` so they can quote it when
    /// reporting an issue, letting us find their events in Sentry.
    public static var sentryUserID: String {
        if Defaults[.sentryUserID].isEmpty {
            Defaults[.sentryUserID] = SERIAL_NUMBER_HASH.isEmpty ? UUID().uuidString : SERIAL_NUMBER_HASH
        }
        return Defaults[.sentryUserID]
    }

    private static var enableSentryObserver: Cancellable?
    private static var sentryLaunchEvent: DispatchWorkItem?
}

// MARK: - SentryToggleRow

/// A "Send error reports" toggle bound to `Defaults[.enableSentry]`.
///
/// The Sentry SDK is reconfigured / closed automatically by `LowtechSentry.configureSentry`'s
/// observer when this default changes, so flipping the toggle is enough.
public struct SentryToggleRow: View {
    public init(title: String = "Send anonymous error reports", subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $enableSentry) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if enableSentry {
                SentryUserIDPill()
            }
        }
    }

    private let title: String
    private let subtitle: String?

    @Default(.enableSentry) private var enableSentry
}

// MARK: - SentryUserIDPill

/// A small click-to-copy pill showing the stable anonymous `LowtechSentry.sentryUserID`.
///
/// Shown under the "Send error reports" toggle when reporting is enabled, so a user
/// can copy their id and send it along with a bug report.
public struct SentryUserIDPill: View {
    public init() {}

    public var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(userID, forType: .string)
            copied = true
            mainAsyncAfter(ms: 1200) { copied = false }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 9, weight: .semibold))
                Text(copied ? "Copied!" : "Machine ID: \(userID)")
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Your anonymous error-report ID. Click to copy and include it when reporting an issue.")
    }

    private let userID = LowtechSentry.sentryUserID
    @State private var copied = false
}

public func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
    guard LowtechSentry.enableSentry else { return }

    let crumb = Breadcrumb(level: level, category: category)
    crumb.message = msg
    SentrySDK.addBreadcrumb(crumb)
}
