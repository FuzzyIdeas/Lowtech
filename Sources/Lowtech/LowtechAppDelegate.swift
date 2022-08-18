import Cocoa
import Combine
import Defaults
import Foundation
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

    @MainActor open func applicationDidFinishLaunching(_ notification: Notification) {
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
            statusBar?.togglePopover(sender: self)
        }
        KM.initHotkeys()
        KM.initFlagsListener()

        if Defaults[.launchCount] == 1, showPopoverOnFirstLaunch {
            mainAsyncAfter(ms: 3000) {
                guard let s = self.statusBar, s.window == nil || !s.window!.isVisible else { return }
                s.showPopover(self)
            }
        }
        initialized = true
        KM.initialized = true
    }

    @MainActor
    @inline(__always)
    open func trialExpired() -> Bool {
        false
    }

    @MainActor
    @inline(__always)
    open func hideTrialOSD() {
        guard trialMode, trialExpired() else {
            return
        }
        trialOSD.ignoresMouseEvents = true
        trialOSD.alphaValue = 0
    }

    @MainActor
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

    public var contentView: AnyView?
    public var accentColor: Color?

    public lazy var trialOSD = OSDWindow(swiftuiView: TrialOSDContainer().any)

    public var appStoreURL: URL?

    public var notificationPopover: PanelWindow! {
        didSet {
            oldValue?.forceClose()
        }
    }

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
        guard let screen = NSScreen.main else { return }
        let view = NotificationView(
            notificationLines: (title.isEmpty ? [] : ["# \(title)"]) + lines,
            yesButtonText: yesButtonText, noButtonText: noButtonText, buttonAction: action
        ).any
        notificationPopover = PanelWindow(swiftuiView: view)
        notificationPopover.show(at: NSPoint(
            x: screen.visibleFrame.maxX - notificationPopover!.contentView!.frame.width,
            y: screen.visibleFrame.maxY - notificationPopover!.contentView!.frame.height
        ), activate: false)
        notificationCloser = mainAsyncAfter(ms: closeMilliseconds) {
            guard let notif = self.notificationPopover, notif.isVisible else { return }
            notif.forceClose()
        }
    }

    public func initMenubar() {
        guard let contentView = contentView else {
            return
        }

        let color = accentColor ?? Colors.yellow
        statusBar = StatusBarController(
            LowtechView(accentColor: color) { contentView }.any
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
