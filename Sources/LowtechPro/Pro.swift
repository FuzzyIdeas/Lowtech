import Combine
import Defaults
import Lowtech
import LowtechIndie
import Paddle
import Sentry

// MARK: - ProManager

public class ProManager: ObservableObject {
    @Published public var pro: LowtechPro? = nil
}

public let PM = ProManager()

public var PRO: LowtechPro? { (LowtechProAppDelegate.instance as? LowtechProAppDelegate)?.pro }

// MARK: - LowtechProAppDelegate

open class LowtechProAppDelegate: LowtechIndieAppDelegate, PADProductDelegate, PaddleDelegate {
    // MARK: Open

    open func getSentryUser() -> User {
        let user = User(userId: SERIAL_NUMBER_HASH)
        guard let product else { return user }
        if Defaults[.paddleConsent] {
            user.email = product.activationEmail
        }
        user.username = product.activationID

        return user
    }

    // MARK: Public

    public static var showNextPaddleError = true

    public static var proDelegate: LowtechProAppDelegate? {
        guard let instance = LowtechAppDelegate.instance else {
            return nil
        }
        return instance as? LowtechProAppDelegate
    }

    public var sentryDSN: String? = nil

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

    public static var enableSentry: Bool = Defaults[.enableSentry]

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

        if let window = statusBar?.window ?? NSApp.windows.first(where: { $0.accessibilityRole() != .popover }), window.isVisible {
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

    public func configureSentry(restartOnHang: Bool) {
        guard let dsn = sentryDSN else { return }
        enableSentryObserver = enableSentryObserver ?? pub(.enableSentry)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { change in
                LowtechProAppDelegate.enableSentry = change.newValue
                if change.newValue {
                    self.configureSentry(restartOnHang: restartOnHang)
                } else {
                    SentrySDK.close()
                }
            }

        guard LowtechProAppDelegate.enableSentry else { return }
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
            scope.setUser(self.getSentryUser())
        }

        guard sentryLaunchEvent == nil, Defaults[.lastLaunchVersion] != release else { return }
        sentryLaunchEvent = mainAsyncAfter(ms: 5000) {
            guard LowtechProAppDelegate.enableSentry else { return }

            SentrySDK.capture(message: "Launch")
            Defaults[.lastLaunchVersion] = release
        }
    }

    // MARK: Internal

    var enableSentryObserver: Cancellable?
    var sentryLaunchEvent: DispatchWorkItem?
}

public func crumb(_ msg: String, level: SentryLevel = .info, category: String) {
    guard LowtechProAppDelegate.enableSentry else { return }

    let crumb = Breadcrumb(level: level, category: category)
    crumb.message = msg
    SentrySDK.addBreadcrumb(crumb)
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

    // MARK: Public

    @Published public var onTrial = false
    @Published public var productActivated = false

    public var active: Bool { productActivated || onTrial }

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
                        print("Differences in \(product.productName ?? "product") after refresh")
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
                    print("\(product.productName ?? "") noActivation")

                    if onTrial {
                        enablePro()
                    } else {
                        disablePro()
                    }
                    if !onTrial {
                        paddle.showProductAccessDialog(with: product)
                    }
                case .unableToVerify where error == nil:
                    print("\(product.productName ?? "Product") unableToVerify (network problems)")
                case .unverified where error?.localizedDescription == "Machine does not match activations.":
                    print("\(product.productName ?? "Product") unableToVerify (machine does not match)")
                    disablePro()
                    if !onTrial {
                        paddle.showProductAccessDialog(with: product)
                    }
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
                    enablePro()
                case PADVerificationState(rawValue: 2):
                    log.error("\(product.productName ?? "Product") verification failed because of network connection: \(state)")
                default:
                    print("\(product.productName ?? "Product") verification unknown state: \(state)")
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
                return timeSince(verifyDate) > (60 * 60 * 24)
            #endif
        } else {
            return timeSince(verifyDate) > (5 * 60)
        }
    }
}
