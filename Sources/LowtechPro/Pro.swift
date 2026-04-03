import Combine
import Defaults
import Lowtech
import LowtechIndie
import Paddle
import Sentry

extension Defaults.Keys {
    static let shownPaddleTrialEnded = Key<Bool>("shownPaddleTrialEnded", default: false)
}

public func clopDebugLog(_ message: String, includeCallStack: Bool = false) {
    guard let bid = Bundle.main.bundleIdentifier, bid.hasPrefix("com.lowtechguys.Clop") else { return }

    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    var line = "[\(df.string(from: Date()))] \(message)\n"
    if includeCallStack {
        line += Thread.callStackSymbols.joined(separator: "\n") + "\n"
    }
    let path = (NSHomeDirectory() as NSString).appendingPathComponent(".clop-debug-logs")
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8)!)
    }
}

// MARK: - ProManager

public class ProManager: ObservableObject {
    @Published public var pro: LowtechPro? = nil
}

public let PM = ProManager()

public var PRO: LowtechPro? { (LowtechProAppDelegate.instance as? LowtechProAppDelegate)?.pro }

// MARK: - LowtechProAppDelegate

open class LowtechProAppDelegate: LowtechIndieAppDelegate, PADProductDelegate, @preconcurrency PaddleDelegate {
    open func getSentryUser() -> User {
        let user = User(userId: SERIAL_NUMBER_HASH)
        guard let product else { return user }
        if Defaults[.paddleConsent] {
            user.email = product.activationEmail
        }
        user.username = product.activationID

        return user
    }

    @MainActor
    open func willShowPaddle(_: PADUIType, product _: PADProduct) -> PADDisplayConfiguration? {
        statusBar?.showPopoverIfNotVisible()

        // if let window = NSApp.windows.first(where: { $0.title.contains("Settings") })
        //     ?? NSApp.windows.first(where: { $0.accessibilityRole() != .popover })
        //     ?? statusBar?.window, window.isVisible
        // {
        //     focus()
        //     window.makeKeyAndOrderFront(nil)
        //     return PADDisplayConfiguration(.sheet, hideNavigationButtons: false, parentWindow: window)
        // }

        return PADDisplayConfiguration(.window, hideNavigationButtons: false, parentWindow: nil)
    }

    @MainActor
    open func willShowPaddle(_ alert: PADAlert) -> Bool {
        if alert.alertType == .error, !LowtechProAppDelegate.showNextPaddleError {
            LowtechProAppDelegate.showNextPaddleError = true

            return false
        }

        return true
    }

    @MainActor
    open func paddleDidError(_ error: Error) {
        clopDebugLog("paddleDidError: code=\((error as NSError).code) description=\(error.localizedDescription)")
        guard let code = PADErrorCode(rawValue: (error as NSError).code) else { return }

        switch code {
        case .licenseCodeUtilized, .tooManyActivationsOrExpired, .noActivations:
            clopDebugLog("paddleDidError: handling \(code.rawValue) (licenseCodeUtilized/tooManyActivations/noActivations)")
            guard let product,
                  let paddleController =
                  (
                      NSApp.windows.compactMap { w in w.sheets.compactMap { s in s.windowController as? PADActivateWindowController }.first }.first
                          ?? NSApp.windows.compactMap { w in w.windowController as? PADActivateWindowController }.first
                  ),
                  let email = paddleController.emailTxt?.stringValue,
                  let licenseCode = paddleController.licenseTxt?.stringValue
            else {
                clopDebugLog("paddleDidError: guard failed (product=\(product != nil), no paddleController or credentials)")
                return
            }

            LowtechProAppDelegate.showNextPaddleError = false
            product.activations(forLicense: licenseCode) { activations, error in
                guard let activationsList = activations as? [[String: Any]], let oldestActivation = activationsList.first
                else {
                    clopDebugLog("paddleDidError: no activations list found, error=\(error?.localizedDescription ?? "nil")")
                    return
                }

                clopDebugLog("paddleDidError: deactivating oldest activation \(oldestActivation["activation_id"] ?? "unknown") to make room")
                product.deactivateActivation(oldestActivation["activation_id"] as! String, license: licenseCode) { deactivated, error in
                    clopDebugLog("paddleDidError: deactivation result=\(deactivated), error=\(error?.localizedDescription ?? "nil")")
                    guard deactivated else { return }
                    mainAsync {
                        product.activateEmail(email, license: licenseCode) { didActivate, error in
                            clopDebugLog("paddleDidError: re-activation result=\(didActivate), error=\(error?.localizedDescription ?? "nil")")
                            guard didActivate else {
                                if let error {
                                    log.error(error.localizedDescription)
                                    paddleController.showErrorAlert(error.localizedDescription)
                                }
                                return
                            }
                            paddleController.closeDialog(.activated, internalUICloseReason: nil)
                        }
                    }
                }
            }
        default:
            break
        }
    }

    public static var showNextPaddleError = true

    public static var proDelegate: LowtechProAppDelegate? {
        guard let instance = LowtechAppDelegate.instance else {
            return nil
        }
        return instance as? LowtechProAppDelegate
    }

    public var paddleVendorID = ""
    public var paddleAPIKey = ""
    public var paddleProductID = ""
    public var productName = ""
    public var vendorName = ""
    public var price: NSNumber = 0
    public var currency = "USD"
    public var trialDays: NSNumber = 7
    public var trialType: PADProductTrialType = .timeLimited
    public var trialText = ""
    public var image = ""
    public var hasFreeFeatures = false

    public lazy var pro = LowtechPro(
        paddleVendorID: paddleVendorID,
        paddleAPIKey: paddleAPIKey,
        paddleProductID: paddleProductID,
        productName: productName,
        vendorName: vendorName,
        price: price,
        currency: currency,
        trialDays: trialDays,
        trialType: trialType,
        trialText: trialText,
        image: image,
        productDelegate: self,
        paddleDelegate: self,
        hasFreeFeatures: hasFreeFeatures
    )

    public func productPurchased(_ checkoutData: PADCheckoutData) {
        Defaults[.paddleConsent] = checkoutData.orderData?.hasMarketingConsent ?? false
    }

    public func productActivated() {
        clopDebugLog("productActivated delegate called")
        pro.enablePro()
    }

    public func productDeactivated() {
        clopDebugLog("productDeactivated delegate called", includeCallStack: true)
        pro.disablePro()
    }

    public func canAutoActivate(_ product: PADProduct) -> Bool {
        guard let email = product.activationEmail, let code = product.licenseCode else {
            return false
        }
        product.activateEmail(email, license: code)
        return true
    }

    #if DEBUG
        @objc public func resetTrial() {
            guard let product else {
                return
            }
            product.resetTrial()
            pro.verifyLicense()
        }

        @objc public func expireTrial() {
            guard let product else {
                return
            }
            product.expireTrial()
            pro.verifyLicense()
        }
    #endif

    @IBAction public func activateLicense(_: Any) {
        pro.showLicenseActivation()
        if let statusBar, let w = statusBar.window, w.isVisible {
            w.makeKeyAndOrderFront(self)
        }
    }

    @IBAction public func recoverLicense(_: Any) {
        guard let paddle, let product else {
            return
        }
        paddle.showLicenseRecovery(for: product) { _, error in
            if let error {
                log.error("Error on recovering license from Paddle: \(error)")
            }
        }
    }

}

public var paddle: Paddle?
public var product: PADProduct?

// MARK: - LowtechPro

public class LowtechPro: ObservableObject {
    public init(
        paddleVendorID: String,
        paddleAPIKey: String,
        paddleProductID: String,
        productName: String,
        vendorName: String,
        price: NSNumber,
        currency: String,
        trialDays: NSNumber,
        trialType: PADProductTrialType,
        trialText: String,
        image: String? = nil,
        productDelegate: PADProductDelegate? = nil,
        paddleDelegate: PaddleDelegate? = nil,
        hasFreeFeatures: Bool = false
    ) {
        self.paddleVendorID = paddleVendorID
        self.paddleAPIKey = paddleAPIKey
        self.paddleProductID = paddleProductID
        self.productName = productName
        self.vendorName = vendorName
        self.price = price
        self.currency = currency
        self.trialDays = trialDays
        self.trialType = trialType
        self.trialText = trialText
        self.image = image
        self.productDelegate = productDelegate
        self.paddleDelegate = paddleDelegate

        paddle = Paddle.sharedInstance(
            withVendorID: paddleVendorID, apiKey: paddleAPIKey, productID: paddleProductID,
            configuration: productConfig, delegate: paddleDelegate
        )
        #if DEBUG
            Paddle.enableDebug()
        #endif

        product = PADProduct(
            productID: paddleProductID, productType: PADProductType.sdkProduct,
            configuration: productConfig
        )

        guard let product else {
            return
        }

        product.delegate = productDelegate
        product.preventFreeUsageBeforeSubscriptionPurchase = !hasFreeFeatures
        product.canForceExit = !hasFreeFeatures
        product.willContinueAtTrialEnd = hasFreeFeatures

        if product.activated || trialActive(product: product) {
            clopDebugLog("LowtechPro.init: enabling pro at init (activated=\(product.activated), trialActive=\(trialActive(product: product)))")
            enablePro()
        } else {
            clopDebugLog("LowtechPro.init: NOT enabling pro at init (activated=\(product.activated), trialActive=\(trialActive(product: product)), licenseCode=\(product.licenseCode != nil ? "present" : "nil"))")
        }
    }

    @Published public var onTrial = false
    @Published public var productActivated = false

    @inline(__always) public var active: Bool { productActivated || onTrial }

    public func manageLicence() {
        guard let paddle, let product else {
            return
        }
        if productActivated {
            paddle.showLicenseActivationDialog(for: product, email: product.activationEmail, licenseCode: product.licenseCode)
        } else {
            paddle.showProductAccessDialog(with: product)
        }
    }

    public func showCheckout() {
        guard let paddle, let product else {
            return
        }

        paddle.showCheckout(
            for: product, options: nil,
            checkoutStatusCompletion: {
                state, _ in
                switch state {
                case .abandoned:
                    log.debug("Checkout abandoned")
                case .failed:
                    log.debug("Checkout failed")
                case .flagged:
                    log.debug("Checkout flagged")
                case .purchased:
                    log.debug("Checkout purchased")
                case .slowOrderProcessing:
                    log.debug("Checkout slow processing")
                default:
                    log.debug("Checkout unknown state: \(state)")
                }
            }
        )
    }

    public func showLicenseActivation() {
        guard let paddle, let product else {
            return
        }

        // if window already exists, focus it instead of opening a new one
        if let w = NSApp.windows.first(where: { $0.windowController is PADActivateWindowController }) {
            w.makeKeyAndOrderFront(self)
            return
        }

        paddle.showLicenseActivationDialog(for: product, email: nil, licenseCode: nil, activationStatusCompletion: { activationStatus in
            mainAsync {
                switch activationStatus {
                case .activated:
                    self.enablePro()
                default:
                    return
                }
            }
        })
    }

    public func licenseExpired(_ product: PADProduct) -> Bool {
        product.licenseCode != nil && (product.licenseExpiryDate ?? Date.distantFuture) < Date()
    }

    public func trialActive(product: PADProduct) -> Bool {
        let hasTrialDaysLeft = (product.trialDaysRemaining ?? NSNumber(value: 0)).intValue > 0

        return hasTrialDaysLeft && (product.licenseCode == nil || licenseExpired(product))
    }

    public func checkProLicense() {
        guard let product else {
            clopDebugLog("checkProLicense: product is nil, returning early")
            return
        }
        clopDebugLog("checkProLicense: starting refresh (activated=\(product.activated), trialDaysRemaining=\(product.trialDaysRemaining ?? -1), licenseCode=\(product.licenseCode != nil ? "present" : "nil"))")
        product.refresh { [self]
            (delta: [AnyHashable: Any]?, error: Error?) in
                mainAsync { [self] in
                    clopDebugLog("checkProLicense: refresh complete (delta=\(delta?.isEmpty == false ? "\(delta!)" : "none"), error=\(error?.localizedDescription ?? "nil"), activated=\(product.activated), trialDaysRemaining=\(product.trialDaysRemaining ?? -1))")
                    if let delta, !delta.isEmpty {
                        log.warning("Differences in \(product.productName ?? "product") after refresh")
                    }
                    if let error {
                        log.error("Error on refreshing \(product.productName ?? "product") from Paddle: \(error)")
                    }

                    if trialActive(product: product) || product.activated {
                        clopDebugLog("checkProLicense: enabling pro (trialActive=\(trialActive(product: product)), activated=\(product.activated))")
                        enablePro()
                    } else {
                        clopDebugLog("checkProLicense: NOT enabling pro (trialActive=\(trialActive(product: product)), activated=\(product.activated))")
                    }

                    verifyLicense()
                }
        }
    }

    public func verifyLicense(force: Bool = false) {
        guard let paddle, let product else {
            clopDebugLog("verifyLicense: paddle=\(paddle != nil), product=\(product != nil), returning early")
            return
        }
        guard force || enoughTimeHasPassedSinceLastVerification(product: product) else {
            clopDebugLog("verifyLicense: skipping (force=\(force), lastVerifyDate=\(product.lastVerifyDate?.description ?? "nil"), productActivated=\(productActivated))")
            return
        }
        clopDebugLog("verifyLicense: calling verifyActivation (force=\(force), activated=\(product.activated), licenseCode=\(product.licenseCode != nil ? "present" : "nil"))")
        product.verifyActivation { [self] (state: PADVerificationState, error: Error?) in
            mainAsync { [self] in
                clopDebugLog("verifyLicense: callback state=\(state.rawValue) error=\(error?.localizedDescription ?? "nil") trialActive=\(trialActive(product: product))")
                if let verificationError = error {
                    log.error(
                        "Error on verifying activation of \(product.productName ?? "product") from Paddle: \(verificationError.localizedDescription)"
                    )
                }

                onTrial = trialActive(product: product)

                switch state {
                case .noActivation:
                    log.debug("\(product.productName ?? "") noActivation")

                    if onTrial {
                        clopDebugLog("verifyLicense: noActivation but onTrial=true, enabling pro")
                        enablePro()
                    } else {
                        clopDebugLog("verifyLicense: noActivation and onTrial=false, DISABLING pro")
                        disablePro()
                    }
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .unableToVerify where error == nil:
                    clopDebugLog("verifyLicense: unableToVerify (network problems), keeping current state (productActivated=\(productActivated), onTrial=\(onTrial))")
                    log.error("\(product.productName ?? "Product") unableToVerify (network problems)")
                case .unverified where error?.localizedDescription == "Machine does not match activations.":
                    clopDebugLog("verifyLicense: unverified (machine mismatch), DISABLING pro")
                    log.error("\(product.productName ?? "Product") unableToVerify (machine does not match)")
                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .unverified where error == nil:
                    if retryUnverified {
                        retryUnverified = false
                        clopDebugLog("verifyLicense: unverified (revoked remotely), retrying in 3s")
                        log.warning("\(product.productName ?? "Product") unverified (revoked remotely), retrying for safe measure")
                        asyncAfter(ms: 3000) {
                            self.verifyLicense(force: true)
                        }
                        return
                    }
                    clopDebugLog("verifyLicense: unverified (revoked remotely) after retry, DISABLING pro")
                    log.error("\(product.productName ?? "Product") unverified (revoked remotely)")

                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .verified:
                    clopDebugLog("verifyLicense: verified, enabling pro")
                    log.info("\(product.productName ?? "Product") verified")
                    enablePro()
                default:
                    clopDebugLog("verifyLicense: unknown state \(state.rawValue)")
                    log.warning("\(product.productName ?? "Product") verification unknown state: \(state)")
                }
            }
        }
    }

    public func enablePro() {
        guard let product else {
            clopDebugLog("enablePro: product is nil, returning early")
            return
        }
        clopDebugLog("enablePro: setting productActivated=true (was \(productActivated), onTrial will be \(trialActive(product: product)))")
        mainAsync {
            self.productActivated = true
            self.onTrial = self.trialActive(product: product)
        }
    }

    public func disablePro() {
        guard let product else {
            clopDebugLog("disablePro: product is nil, returning early")
            return
        }
        clopDebugLog("disablePro: setting productActivated=false (was \(productActivated), onTrial will be \(trialActive(product: product)))", includeCallStack: true)
        mainAsync {
            self.productActivated = false
            self.onTrial = self.trialActive(product: product)
        }
    }

    let paddleVendorID: String
    let paddleAPIKey: String
    let paddleProductID: String
    let productName: String
    let vendorName: String
    let price: NSNumber
    let currency: String
    let trialDays: NSNumber
    let trialType: PADProductTrialType
    let trialText: String
    let image: String?

    weak var productDelegate: PADProductDelegate?
    weak var paddleDelegate: PaddleDelegate?

    lazy var productConfig: PADProductConfiguration = {
        let defaultProductConfig = PADProductConfiguration()
        defaultProductConfig.productName = productName
        defaultProductConfig.vendorName = vendorName
        defaultProductConfig.price = price
        defaultProductConfig.currency = currency
        defaultProductConfig.imagePath = Bundle.main.pathForImageResource(image ?? "AppIcon")
        defaultProductConfig.trialLength = trialDays
        defaultProductConfig.trialType = trialType
        defaultProductConfig.trialText = trialText

        return defaultProductConfig
    }()

    var retryUnverified = true

    @inline(__always) func enoughTimeHasPassedSinceLastVerification(product: PADProduct) -> Bool {
        guard let verifyDate = product.lastVerifyDate else {
            return true
        }
        if productActivated {
            #if DEBUG
                return true
            #else
                return timeSince(verifyDate) > (60 * 60 * 24 * 7)
            #endif
        } else {
            return timeSince(verifyDate) > (5 * 60)
        }
    }
}
