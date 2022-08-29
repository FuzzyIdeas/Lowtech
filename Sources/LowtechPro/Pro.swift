import Combine
import Defaults
import Lowtech
import LowtechIndie
import Paddle
import SwiftDate

// MARK: - LowtechProAppDelegate

open class LowtechProAppDelegate: LowtechIndieAppDelegate, PADProductDelegate, PaddleDelegate {
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
        paddleDelegate: self
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
            guard let product = product else {
                return
            }
            product.resetTrial()
            pro.verifyLicense()
        }

        @objc public func expireTrial() {
            guard let product = product else {
                return
            }
            product.expireTrial()
            pro.verifyLicense()
        }
    #endif

    @IBAction public func activateLicense(_: Any) {
        pro.showLicenseActivation()
        if let statusBar = statusBar, let w = statusBar.window, w.isVisible {
            w.makeKeyAndOrderFront(self)
        }
    }

    @IBAction public func recoverLicense(_: Any) {
        guard let paddle = paddle, let product = product else {
            return
        }
        paddle.showLicenseRecovery(for: product) { _, error in
            if let error = error {
                printerr("Error on recovering license from Paddle: \(error)")
            }
        }
    }

    public func willShowPaddle(_: PADUIType, product _: PADProduct) -> PADDisplayConfiguration? {
        statusBar?.showPopoverIfNotVisible()

        if let window = statusBar?.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return PADDisplayConfiguration(.sheet, hideNavigationButtons: false, parentWindow: window)
        }

        return PADDisplayConfiguration(.window, hideNavigationButtons: false, parentWindow: nil)
    }
}

public var paddle: Paddle?
public var product: PADProduct?

// MARK: - LowtechPro

public class LowtechPro: ObservableObject {
    // MARK: Lifecycle

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
        paddleDelegate: PaddleDelegate? = nil
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

        product = PADProduct(
            productID: paddleProductID, productType: PADProductType.sdkProduct,
            configuration: productConfig
        )

        guard let product = product else {
            return
        }

        product.delegate = productDelegate
        product.preventFreeUsageBeforeSubscriptionPurchase = true
        product.canForceExit = true
        product.willContinueAtTrialEnd = false

        if product.activated || trialActive(product: product) {
            enablePro()
        }
    }

    // MARK: Public

    @Published public var onTrial = false
    @Published public var productActivated = false

    public var active: Bool { productActivated || onTrial }

    public func manageLicence() {
        guard let paddle = paddle, let product = product else {
            return
        }
        paddle.showProductAccessDialog(with: product)
    }

    public func showCheckout() {
        guard let paddle = paddle, let product = product else {
            return
        }

        paddle.showCheckout(
            for: product, options: nil,
            checkoutStatusCompletion: {
                state, _ in
                switch state {
                case .abandoned:
                    print("Checkout abandoned")
                case .failed:
                    print("Checkout failed")
                case .flagged:
                    print("Checkout flagged")
                case .purchased:
                    print("Checkout purchased")
                case .slowOrderProcessing:
                    print("Checkout slow processing")
                default:
                    print("Checkout unknown state: \(state)")
                }
            }
        )
    }

    public func showLicenseActivation() {
        guard let paddle = paddle, let product = product else {
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
        product.licenseCode != nil && (product.licenseExpiryDate ?? Date.distantFuture).isInPast
    }

    public func trialActive(product: PADProduct) -> Bool {
        let hasTrialDaysLeft = (product.trialDaysRemaining ?? NSNumber(value: 0)).intValue > 0

        return hasTrialDaysLeft && (product.licenseCode == nil || licenseExpired(product))
    }

    public func checkProLicense() {
        guard let product = product else {
            return
        }
        product.refresh { [self]
            (delta: [AnyHashable: Any]?, error: Error?) in
                mainAsync { [self] in
                    if let delta = delta, !delta.isEmpty {
                        print("Differences in \(product.productName ?? "product") after refresh")
                    }
                    if let error = error {
                        printerr("Error on refreshing \(product.productName ?? "product") from Paddle: \(error)")
                    }

                    if trialActive(product: product) || product.activated {
                        self.enablePro()
                    }

                    self.verifyLicense()
                }
        }
    }

    public func verifyLicense(force: Bool = false) {
        guard let paddle = paddle, let product = product else {
            return
        }
        guard force || enoughTimeHasPassedSinceLastVerification(product: product) else { return }
        product.verifyActivation { [self] (state: PADVerificationState, error: Error?) in
            mainAsync { [self] in
                if let verificationError = error {
                    printerr(
                        "Error on verifying activation of \(product.productName ?? "product") from Paddle: \(verificationError.localizedDescription)"
                    )
                }

                onTrial = trialActive(product: product)

                switch state {
                case .noActivation:
                    print("\(product.productName ?? "") noActivation")

                    if onTrial {
                        self.enablePro()
                    } else {
                        self.disablePro()
                    }
                    if !onTrial {
                        paddle.showProductAccessDialog(with: product)
                    }
                case .unableToVerify where error == nil:
                    print("\(product.productName ?? "Product") unableToVerify (network problems)")
                case .unverified where error == nil:
                    if retryUnverified {
                        retryUnverified = false
                        print("\(product.productName ?? "Product") unverified (revoked remotely), retrying for safe measure")
                        asyncAfter(ms: 3000) {
                            self.verifyLicense(force: true)
                        }
                        return
                    }
                    print("\(product.productName ?? "Product") unverified (revoked remotely)")

                    disablePro()
                    if !onTrial {
                        paddle.showProductAccessDialog(with: product)
                    }
                case .verified:
                    print("\(product.productName ?? "Product") verified")
                    self.enablePro()
                case PADVerificationState(rawValue: 2):
                    printerr("\(product.productName ?? "Product") verification failed because of network connection: \(state)")
                default:
                    print("\(product.productName ?? "Product") verification unknown state: \(state)")
                }
            }
        }
    }

    public func enablePro() {
        guard let product = product else {
            return
        }
        productActivated = true
        onTrial = trialActive(product: product)
    }

    public func disablePro() {
        guard let product = product else {
            return
        }
        productActivated = false
        onTrial = trialActive(product: product)
    }

    // MARK: Internal

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
        defaultProductConfig.imagePath = image != nil ? Bundle.main.pathForImageResource(image!) : nil
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
                return timeSince(verifyDate) > 1.days.timeInterval
            #endif
        } else {
            return timeSince(verifyDate) > 5.minutes.timeInterval
        }
    }
}
