import Combine
import Defaults
import Lowtech
import LowtechIndie
import os
@preconcurrency import Paddle

private let logger = Logger(subsystem: lowtechLogSubsystem, category: "Pro")

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

open class LowtechProAppDelegate: LowtechIndieAppDelegate, PADProductDelegate, @preconcurrency PaddleDelegate {
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
            LowtechProAppDelegate.heldPaddleErrorMessage = alert.message

            return false
        }

        return true
    }

    @MainActor
    open func paddleDidError(_ error: Error) {
        let nsError = error as NSError
        logger.error("Paddle error \(nsError.domain) \(nsError.code): \(nsError.localizedDescription)")
        guard nsError.domain == PADErrorDomain, let code = PADErrorCode(rawValue: nsError.code) else { return }

        switch code {
        case .licenseCodeUtilized, .tooManyActivationsOrExpired, .noActivations:
            freeActivationSlot(onlyIfFull: false)
        case .unableToActivate:
            // A licence at its limit can come back as Paddle's generic activation error instead of
            // one of the codes above
            freeActivationSlot(onlyIfFull: true)
        default:
            break
        }
    }

    public static var showNextPaddleError = true

    /// How many activations a licence comes with. Only gates freeing a slot on Paddle's generic
    /// activation error, so a licence given more seats by hand still frees one on the specific errors.
    public var licenseActivations = 5


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
                logger.error("Error on recovering license from Paddle: \(error)")
            }
        }
    }

    /// The message of the Paddle error alert held back while `freeActivationSlot` works, shown after
    /// all when it gives up.
    static var heldPaddleErrorMessage: String?
    static var freeingActivationSlot = false

    /// Paddle error codes whose own text the activation dialog shows. Every other code gets Paddle's
    /// generic "unable to complete the license activation" text.
    static let paddleErrorsWithOwnMessage: Set<Int> = [-122, -123, -124, -125, -126, -131]

    /// Paddle refuses one more Mac than the licence allows instead of freeing a slot, so a wiped or
    /// replaced Mac can't activate until an activation is released. This deactivates the oldest
    /// activation and activates again with the email and code typed in the dialog.
    ///
    /// Paddle calls `paddleDidError` right before it shows its error alert, so the alert is held back
    /// here and only shown if freeing a slot fails. `onlyIfFull` is for Paddle's generic error, which
    /// also covers a blocked network or a refused licence: then a slot is only freed when the licence
    /// lists at least `licenseActivations` activations.
    private func freeActivationSlot(onlyIfFull: Bool) {
        guard !LowtechProAppDelegate.freeingActivationSlot, let product,
              let paddleController =
              (
                  NSApp.windows.compactMap { w in w.sheets.compactMap { s in s.windowController as? PADActivateWindowController }.first }.first
                      ?? NSApp.windows.compactMap { w in w.windowController as? PADActivateWindowController }.first
              ),
              let email = paddleController.emailTxt?.stringValue.trimmed, !email.isEmpty,
              let licenseCode = paddleController.licenseTxt?.stringValue.trimmed, !licenseCode.isEmpty
        else {
            return
        }

        LowtechProAppDelegate.freeingActivationSlot = true
        LowtechProAppDelegate.heldPaddleErrorMessage = nil
        LowtechProAppDelegate.showNextPaddleError = false

        let licenseActivations = licenseActivations
        func giveUp(_ reason: String, error: Error? = nil) {
            logger.error("Not freeing an activation slot: \(reason) \(error?.localizedDescription ?? "")")
            LowtechProAppDelegate.freeingActivationSlot = false
            LowtechProAppDelegate.showNextPaddleError = true
            guard let message = LowtechProAppDelegate.heldPaddleErrorMessage else { return }
            LowtechProAppDelegate.heldPaddleErrorMessage = nil
            paddleController.showErrorAlert(message)
        }

        product.activations(forLicense: licenseCode) { activations, error in mainAsync {
            guard let activations = activations as? [[String: Any]], !activations.isEmpty else {
                giveUp("listing the activations failed", error: error)
                return
            }
            guard !onlyIfFull || activations.count >= licenseActivations else {
                giveUp("\(activations.count) activations, the licence isn't full")
                return
            }
            // Paddle lists them oldest first; sort by the date anyway and keep that order for ties
            let oldest = activations.enumerated().min { a, b in
                (a.element["activated"] as? Date ?? .distantFuture, a.offset) < (b.element["activated"] as? Date ?? .distantFuture, b.offset)
            }?.element
            guard let activationID = (oldest?["activation_id"] as? String) ?? (oldest?["activation_id"] as? NSNumber)?.stringValue else {
                giveUp("the oldest activation has no ID")
                return
            }

            product.deactivateActivation(activationID, license: licenseCode) { deactivated, error in mainAsync {
                guard deactivated else {
                    giveUp("deactivating \(activationID) failed", error: error)
                    return
                }
                logger.info("Deactivated the oldest activation \(activationID) of \(activations.count) to activate this Mac")

                product.activateEmail(email, license: licenseCode) { activated, error in mainAsync {
                    LowtechProAppDelegate.freeingActivationSlot = false
                    LowtechProAppDelegate.showNextPaddleError = true
                    let heldMessage = LowtechProAppDelegate.heldPaddleErrorMessage
                    LowtechProAppDelegate.heldPaddleErrorMessage = nil

                    guard activated else {
                        logger.error("Activating after freeing a slot failed: \(error?.localizedDescription ?? "unknown error")")
                        let ownMessage = (error as NSError?).flatMap { LowtechProAppDelegate.paddleErrorsWithOwnMessage.contains($0.code) ? $0.localizedDescription : nil }
                        if let message = ownMessage ?? heldMessage ?? error?.localizedDescription {
                            paddleController.showErrorAlert(message)
                        }
                        return
                    }
                    self.pro.enablePro()
                    paddleController.closeDialog(.activated, internalUICloseReason: nil)
                }}
            }}
        }}
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
                    logger.debug("Checkout abandoned")
                case .failed:
                    logger.debug("Checkout failed")
                case .flagged:
                    logger.debug("Checkout flagged")
                case .purchased:
                    logger.debug("Checkout purchased")
                case .slowOrderProcessing:
                    logger.debug("Checkout slow processing")
                default:
                    logger.debug("Checkout unknown state: \(state.rawValue)")
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
            return
        }
        product.refresh { [self]
            (delta: [AnyHashable: Any]?, error: Error?) in
                mainAsync { [self] in
                    if let delta, !delta.isEmpty {
                        logger.warning("Differences in \(product.productName ?? "product") after refresh")
                    }
                    if let error {
                        logger.error("Error on refreshing \(product.productName ?? "product") from Paddle: \(error)")
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
        guard force || enoughTimeHasPassedSinceLastVerification(product: product) else {
            return
        }
        product.verifyActivation { [self] (state: PADVerificationState, error: Error?) in
            mainAsync { [self] in
                if let verificationError = error {
                    logger.error(
                        "Error on verifying activation of \(product.productName ?? "product") from Paddle: \(verificationError.localizedDescription)"
                    )
                }

                onTrial = trialActive(product: product)

                switch state {
                case .noActivation:
                    logger.debug("\(product.productName ?? "") noActivation")

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
                    logger.error("\(product.productName ?? "Product") unableToVerify (network problems)")
                case .unverified where error?.localizedDescription == "Machine does not match activations.":
                    logger.error("\(product.productName ?? "Product") unableToVerify (machine does not match)")
                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .unverified where error == nil:
                    if retryUnverified {
                        retryUnverified = false
                        logger.warning("\(product.productName ?? "Product") unverified (revoked remotely), retrying for safe measure")
                        asyncAfter(ms: 3000) {
                            self.verifyLicense(force: true)
                        }
                        return
                    }
                    logger.error("\(product.productName ?? "Product") unverified (revoked remotely)")

                    disablePro()
                    if !onTrial, !Defaults[.shownPaddleTrialEnded] {
                        paddle.showProductAccessDialog(with: product)
                        Defaults[.shownPaddleTrialEnded] = true
                    }
                case .verified:
                    logger.info("\(product.productName ?? "Product") verified")
                    enablePro()
                default:
                    logger.warning("\(product.productName ?? "Product") verification unknown state: \(state.rawValue)")
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
