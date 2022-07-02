import Cocoa
import Combine
import Defaults
import Foundation
import Magnet
import SwiftUI

// MARK: - LowtechAppDelegate

open class LowtechAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: Open

    @Published open var showPopoverOnSpecialKey = true

    open var initialized = false

    open func isTrialMode() -> Bool {
        false
    }

    open func applicationDidBecomeActive(_ notification: Notification) {
        #if DEBUG
            print(notification)
        #endif
        if Defaults[.hideMenubarIcon] {
            statusBar?.showPopoverIfNotVisible()
        }
    }

    open func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            print(notification)
        #endif

        LowtechAppDelegate.instance = self
        Defaults[.launchCount] += 1

        initMenubar()
        KM.onSpecialHotkey = { [self] in
            guard showPopoverOnSpecialKey else {
                return
            }
            statusBar?.togglePopover(sender: self, at: .mouseLocation(centeredOn: statusBar?.window))
        }
        KM.initHotkeys()
        KM.initFlagsListener()

        if Defaults[.launchCount] == 1, showPopoverOnFirstLaunch {
            mainAsyncAfter(ms: 3000) {
                guard let s = self.statusBar, !s.popover.isShown else { return }
                s.showPopover(self)
            }
        }
        initialized = true
        KM.initialized = true
    }

    open func trialExpired() -> Bool {
        false
    }

    @inline(__always)
    open func hideTrialOSD() {
        guard trialMode, trialExpired() else {
            return
        }
        trialOSD.ignoresMouseEvents = true
        trialOSD.alphaValue = 0
    }

    @inline(__always)
    open func showTrialOSD() {
        guard trialMode, trialExpired() else {
            return
        }
        trialOSD.ignoresMouseEvents = false
        trialOSD.show(closeAfter: 0, fadeAfter: 0, offCenter: 0, centerWindow: false, corner: .bottomRight, screen: .main)
    }

    // MARK: Public

    public private(set) static var instance: LowtechAppDelegate!

    public lazy var trialMode = isTrialMode()

    public var showPopoverOnFirstLaunch = true
    public var statusBar: StatusBarController?
    public var application = NSApplication.shared

    public var observers: Set<AnyCancellable> = []

    public lazy var notificationPopover: LowtechPopover = {
        let p = LowtechPopover(statusBar)
        p.contentViewController = MainViewController()
        p.animates = false
        p.contentViewController?.view = HostingView(rootView: notificationView)

        return p
    }()

    public var notificationView: AnyView?
    public var contentView: AnyView?
    public var accentColor: Color?

    public lazy var trialOSD = OSDWindow(swiftuiView: TrialOSDContainer().any)

    public var appStoreURL: URL?

    public var notificationCloser: DispatchWorkItem? {
        didSet {
            guard let oldCloser = oldValue else {
                return
            }
            oldCloser.cancel()
        }
    }

    public func hidePopover() {
        statusBar?.hidePopover(self)
    }

    public func showNotification(
        title: String,
        lines: [String],
        yesButtonText: String? = nil,
        noButtonText: String? = nil,
        closeAfter closeMilliseconds: Int = 4000,
        menubarIconHidden: Bool? = nil,
        action: ((Bool) -> Void)? = nil
    ) {
        notificationPopover.contentViewController?.view = HostingView(rootView: NotificationView(
            notificationLines: (title.isEmpty ? [] : ["# \(title)"]) + lines,
            yesButtonText: yesButtonText, noButtonText: noButtonText, buttonAction: action
        ))
        notificationPopover.show(menubarIconHidden: menubarIconHidden)
        notificationPopover.contentViewController?.view.window?.makeKeyAndOrderFront(self)
        notificationCloser = mainAsyncAfter(ms: closeMilliseconds) {
            guard self.notificationPopover.isShown else { return }
            self.notificationPopover.close()
        }
    }

    public func initMenubar() {
        guard let contentView = contentView else {
            return
        }

        statusBar = StatusBarController(
            HostingView(
                rootView: AnyView(LowtechView(accentColor: accentColor ?? Colors.yellow) { contentView })
            )
        )
    }
}

import AppReceiptValidator

@inline(__always)
public func validReceipt() -> Bool {
    switch AppReceiptValidator().validateReceipt() {
    case .success(_, receiptData: _, deviceIdentifier: _):
        return true
    default:
        return false
    }
}
