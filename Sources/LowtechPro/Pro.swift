import Combine
import Defaults
import Lowtech
import LowtechIndie
import Paddle
import Sentry

extension Defaults.Keys {
    static let shownPaddleTrialEnded = Key<Bool>("shownPaddleTrialEnded", default: false)
}

// MARK: - ProManager

public class ProManager: ObservableObject {
    @Published public var pro: LowtechPro? = nil
}

public let PM = ProManager()

public var PRO: LowtechPro? { (LowtechProAppDelegate.instance as? LowtechProAppDelegate)?.pro }

// MARK: - LowtechProAppDelegate

open class LowtechProAppDelegate: LowtechIndieAppDelegate, PADProductDelegate, PaddleDelegate {
    open func getSentryUser() -> User {
        let user = User(userId: SERIAL_NUMBER_HASH)
        guard let product else { return user }
        if Defaults[.paddleConsent] {
            user.email = product.activationEmail
        }
        user.username = product.activationID

        return user
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
        pro.enablePro()
    }

    public func productDeactivated() {
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

    @MainActor
    public func willShowPaddle(_: PADUIType, product _: PADProduct) -> PADDisplayConfiguration? {
        statusBar?.showPopoverIfNotVisible()

        if let window = NSApp.windows.first(where: { $0.title.contains("Settings") })
            ?? NSApp.windows.first(where: { $0.accessibilityRole() != .popover })
            ?? statusBar?.window, window.isVisible
        {
            focus()
            window.makeKeyAndOrderFront(nil)
            return PADDisplayConfiguration(.sheet, hideNavigationButtons: false, parentWindow: window)
        }

        return PADDisplayConfiguration(.window, hideNavigationButtons: false, parentWindow: nil)
    }

    @MainActor
    public func willShowPaddle(_ alert: PADAlert) -> Bool {
        if alert.alertType == .error, !LowtechProAppDelegate.showNextPaddleError {
            LowtechProAppDelegate.showNextPaddleError = true

            return false
        }

        return true
    }

    @MainActor
    public func paddleDidError(_ error: Error) {
        guard let code = PADErrorCode(rawValue: (error as NSError).code) else { return }

        switch code {
        case .licenseCodeUtilized, .tooManyActivationsOrExpired, .noActivations:
            guard let product,
                  let s = statusBar, let window = s.window,
                  let sheet = window.sheets.first,
                  let paddleController = sheet.windowController as? PADActivateWindowController,
                  let email = paddleController.emailTxt?.stringValue,
                  let licenseCode = paddleController.licenseTxt?.stringValue
            else { return }

            LowtechProAppDelegate.showNextPaddleError = false
            product.activations(forLicense: licenseCode) { activations, error in
                guard let activationsList = activations as? [[String: Any]], let oldestActivation = activationsList.first
                else { return }

                product.deactivateActivation(oldestActivation["activation_id"] as! String, license: licenseCode) { deactivated, error in
                    guard deactivated else { return }
                    mainAsync {
                        product.activateEmail(email, license: licenseCode) { didActivate, error in
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
            enablePro()
        }
    }

    @Published public var onTrial = false
    @Published public var productActivated = false

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
            return
        }
        product.refresh { [self]
            (delta: [AnyHashable: Any]?, error: Error?) in
                mainAsync { [self] in
                    if let delta, !delta.isEmpty {
                        log.warning("Differences in \(product.productName ?? "product") after refresh")
                    }
                    if let error {
                        log.error("Error on refreshing \(product.productName ?? "product") from Paddle: \(error)")
                    }

                    if trialActive(product: product) || product.activated {
                        enablePro()
                    }

                    verifyLicense()
                }
        }
    }

    public func verifyLicense(force: Bool = false) {
        guard let paddle, let product else {
            return
        }
        guard force || enoughTimeHasPassedSinceLastVerification(product: product) else { return }
        product.verifyActivation { [self] (state: PADVerificationState, error: Error?) in
            mainAsync { [self] in
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
                        enablePro()
                    } else {
                        disablePro()
                    }
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .unableToVerify where error == nil:
                    log.error("\(product.productName ?? "Product") unableToVerify (network problems)")
                case .unverified where error?.localizedDescription == "Machine does not match activations.":
                    log.error("\(product.productName ?? "Product") unableToVerify (machine does not match)")
                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .unverified where error == nil:
                    if retryUnverified {
                        retryUnverified = false
                        log.warning("\(product.productName ?? "Product") unverified (revoked remotely), retrying for safe measure")
                        asyncAfter(ms: 3000) {
                            self.verifyLicense(force: true)
                        }
                        return
                    }
                    log.error("\(product.productName ?? "Product") unverified (revoked remotely)")

                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .verified:
                    log.info("\(product.productName ?? "Product") verified")
                    enablePro()
                default:
                    log.warning("\(product.productName ?? "Product") verification unknown state: \(state)")
                }
            }
        }
    }

    public func enablePro() {
        guard let product else {
            return
        }
        mainAsync {
            self.productActivated = true
            self.onTrial = self.trialActive(product: product)
        }
    }

    public func disablePro() {
        guard let product else {
            return
        }
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

    @inline(__always) var active: Bool { productActivated || onTrial }

    @inline(__always) func enoughTimeHasPassedSinceLastVerification(product: PADProduct) -> Bool {
        guard let verifyDate = product.lastVerifyDate else {
            return true
        }
        if productActivated {
            #if DEBUG
                return true
            #else
                return timeSince(verifyDate) > (60 * 60 * 24)
            #endif
        } else {
            return timeSince(verifyDate) > (5 * 60)
        }
    }
}
