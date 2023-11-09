import Combine
import Defaults
import Lowtech
import Sentry

public extension Defaults.Keys {
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let lastLaunchVersion = Key<String>("lastLaunchVersion", default: "")
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
            options.appHangTimeoutInterval = 30
            options.swiftAsyncStacktraces = true
            if restartOnHang {
                options.beforeSend = { event in
                    if let exc = event.exceptions?.first, let mech = exc.mechanism, mech.type == "AppHang", let stack = exc.stacktrace {
                        log.warning("App Hanging: \(stack)")
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
