import Defaults
import Lowtech
import Sparkle

// MARK: - UpdateCheckInterval

enum UpdateCheckInterval: Int {
    case daily = 86400
    case everyThreeDays = 259_200
    case weekly = 604_800
}

extension Defaults.Keys {
    static let silentUpdates = Key<Bool>("SUAutomaticallyUpdate", default: false)
    static let checkForUpdates = Key<Bool>("SUEnableAutomaticChecks", default: true)
    static let updateCheckInterval = Key<Int>("SUScheduledCheckInterval", default: 86400)
}

// MARK: - LowtechIndieAppDelegate

open class LowtechIndieAppDelegate: LowtechAppDelegate, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    public lazy var updateController = initUpdater()

    func initUpdater() -> SPUStandardUpdaterController {
        SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    }
}
