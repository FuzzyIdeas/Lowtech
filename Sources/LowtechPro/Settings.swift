import Defaults

public extension Defaults.Keys {
    static let paddleConsent = Key<Bool>("paddleConsent", default: false)
    static let enableSentry = Key<Bool>("enableSentry", default: true)
    static let lastLaunchVersion = Key<String>("lastLaunchVersion", default: "")
}
