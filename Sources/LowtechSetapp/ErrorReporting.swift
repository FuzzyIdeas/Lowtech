import Combine
import Defaults
import Lowtech
import Sentry

public extension Defaults.Keys {
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let lastLaunchVersion = Key<String>("lastLaunchVersion", default: "")
}

extension SentryStacktrace? {
    var isExpectedToHang: Bool {
        guard let stack = self else {
            return true
        }
        return stack.frames.contains { frame in
            guard let function = frame.function else { return false }
            return function.contains("runModal") || function.contains("forTimeInterval")
        }
    }
}

public enum LowtechSentry {
    public static var enableSentry: Bool = Defaults[.enableSentry]
    public static var sentryDSN: String?

    public static func configureSentry(restartOnHang: Bool, getUser: @escaping () -> User) {
        guard let dsn = sentryDSN else { return }
        enableSentryObserver = enableSentryObserver ?? pub(.enableSentry)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { change in
                enableSentry = change.newValue
                if change.newValue {
                    configureSentry(restartOnHang: restartOnHang, getUser: getUser)
                } else {
                    SentrySDK.close()
                }
            }

        guard enableSentry else { return }
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

        let release = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = "v\(release)"
            options.dist = release
            #if DEBUG
                options.appHangTimeoutInterval = 3
            #else
                options.appHangTimeoutInterval = 30
            #endif
            options.swiftAsyncStacktraces = true
            if restartOnHang {
                options.beforeSend = { event in
                    if let exc = event.exceptions?.first, let mech = exc.mechanism, mech.type == "AppHang", exc.stacktrace.isExpectedToHang {
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
        User(userId: SERIAL_NUMBER_HASH)
    }

    private static var enableSentryObserver: Cancellable?
    private static var sentryLaunchEvent: DispatchWorkItem?
}

public func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
    guard LowtechSentry.enableSentry else { return }

    let crumb = Breadcrumb(level: level, category: category)
    crumb.message = msg
    SentrySDK.addBreadcrumb(crumb)
}
