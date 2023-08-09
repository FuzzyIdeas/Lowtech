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

// MARK: - UpdateManager

public class UpdateManager: ObservableObject {
    @Published public var newVersion: String? = nil
    @Published public var updater: SPUUpdater? = nil
}

public let UM = UpdateManager()

// MARK: - LowtechIndieAppDelegate

open class LowtechIndieAppDelegate: LowtechAppDelegate, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    public static var indieDelegate: LowtechIndieAppDelegate? {
        guard let instance = LowtechAppDelegate.instance else {
            return nil
        }
        return instance as? LowtechIndieAppDelegate
    }

    public lazy var updateController = initUpdater()

    public var supportsGentleScheduledUpdateReminders: Bool { true }

    public func standardUserDriverShouldHandleShowingScheduledUpdate(_: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // If the standard user driver will show the update in immediate focus (e.g. near app launch),
        // then let Sparkle take care of showing the update.
        // Otherwise we will handle showing any other scheduled updates
        immediateFocus
    }

    public func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state _: SPUUserUpdateState) {
        // We will ignore updates that the user driver will handle showing
        // This includes user initiated (non-scheduled) updates
        guard !handleShowingUpdate else {
            return
        }

        // Attach a gentle UI indicator on our window
        UM.newVersion = update.displayVersionString
    }

    public func standardUserDriverWillFinishUpdateSession() {
        // We will dismiss our gentle UI indicator if the user session for the update finishes
        UM.newVersion = nil
    }

    func initUpdater() -> SPUStandardUpdaterController {
        let up = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        up.startUpdater()
        return up
    }
}

public func checkForUpdates() {
    (LowtechIndieAppDelegate.instance as? LowtechIndieAppDelegate)?.updateController.checkForUpdates(nil)
}
