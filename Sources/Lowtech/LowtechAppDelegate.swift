import Cocoa
import Combine
import Defaults
import Foundation
import Magnet
import SwiftUI

open class LowtechAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: Open

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
        initHotkeys()
        initFlagsListener()

        if Defaults[.launchCount] == 1 {
            mainAsyncAfter(ms: 1000) {
                self.statusBar?.showPopover(self)
            }
        }
    }

    // MARK: Public

    public private(set) static var instance: LowtechAppDelegate!

    public var statusBar: StatusBarController?
    public var application = NSApplication.shared

    public var globalEventMonitor: GlobalEventMonitor!
    public var localEventMonitor: LocalEventMonitor!

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

    @Published public var showPopoverModifiers: [TriggerKey] = [.ralt]
    public var hotkeys: [HotKey] = []
    public lazy var showPopoverIdentifier = "SHOW_POPOVER\(showPopoverKey)"

    @Atomic public var hotkeysRegistered = false

    public var notificationCloser: DispatchWorkItem? {
        didSet {
            guard let oldCloser = oldValue else {
                return
            }
            oldCloser.cancel()
        }
    }

    @Published public var showPopoverKey = "" {
        didSet {
            showPopoverIdentifier = "SHOW_POPOVER\(showPopoverKey)"
        }
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
            notificationLines: ["# \(title)"] + lines,
            yesButtonText: yesButtonText, noButtonText: noButtonText, buttonAction: action
        ))
        notificationPopover.show(menubarIconHidden: menubarIconHidden)
        notificationPopover.contentViewController?.view.window?.makeKeyAndOrderFront(self)
        notificationCloser = mainAsyncAfter(ms: closeMilliseconds) {
            guard self.notificationPopover.isShown else { return }
            self.notificationPopover.close()
        }
    }

    @objc public func onHotkey(_: HotKey) {}

    @objc public func handleHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard showPopoverModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard hotkey.identifier != showPopoverIdentifier else {
            statusBar?.togglePopover(sender: self, at: .mouseLocation(centeredOn: statusBar?.window))
            return
        }
        onHotkey(hotkey)
    }

    public func initHotkeys() {
        if !showPopoverKey.isEmpty, !showPopoverModifiers.isEmpty {
            hotkeys = buildHotkeys(
                for: [showPopoverKey],
                modifiers: showPopoverModifiers.sideIndependentModifiers,
                action: #selector(handleHotkey(_:)),
                identifier: "SHOW_POPOVER",
                detectKeyHold: false
            )
        }
    }

    public func initMenubar() {
        guard let contentView = contentView else {
            return
        }

        statusBar = StatusBarController(HostingView(rootView: contentView))
    }

    public func onFlagsChanged(event: NSEvent) {
        rcmd = event.modifierFlags.contains(.rightCommand)
        ralt = event.modifierFlags.contains(.rightOption)
        rshift = event.modifierFlags.contains(.rightShift)
        rctrl = event.modifierFlags.contains(.rightControl)
        lcmd = (!event.modifierFlags.intersection([.leftCommand, .command]).isEmpty && !rcmd)
        lalt = (!event.modifierFlags.intersection([.leftOption, .option]).isEmpty && !ralt)
        lctrl = (!event.modifierFlags.intersection([.leftControl, .control]).isEmpty && !rctrl)
        lshift = (!event.modifierFlags.intersection([.leftShift, .shift]).isEmpty && !rshift)

        if showPopoverModifiers.allPressed {
            registerHotkeys()
        } else {
            unregisterHotkeys()
        }
    }

    public func initFlagsListener() {
        globalEventMonitor = GlobalEventMonitor(mask: .flagsChanged) { [self] event in
            guard let event = event else { return }
            onFlagsChanged(event: event)
        }
        globalEventMonitor.start()

        localEventMonitor = LocalEventMonitor(mask: .flagsChanged) { [self] event in
            onFlagsChanged(event: event)
            return event
        }
        localEventMonitor.start()
    }

    public func buildHotkeys(
        for keys: [String],
        modifiers: NSEvent.ModifierFlags,
        action: Selector,
        identifier: String = "",
        detectKeyHold: Bool = false
    ) -> [HotKey] {
        Set(keys).map { ch in
            HotKey(
                identifier: "\(identifier)\(ch)",
                keyCombo: KeyCombo(key: .init(character: ch, virtualKeyCode: nil)!, cocoaModifiers: modifiers)!,
                target: self,
                action: action,
                actionQueue: .main,
                detectKeyHold: detectKeyHold
            )
        }
    }

    public func registerHotkeys() {
        guard !hotkeysRegistered else { return }
        hotkeys.forEach { $0.register() }
        hotkeysRegistered = true
    }

    public func unregisterHotkeys() {
        guard hotkeysRegistered else { return }
        hotkeys.forEach { $0.unregister() }
        hotkeysRegistered = false
    }
}
