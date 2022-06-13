import Cocoa
import Combine
import Defaults
import Foundation
import Magnet
import SwiftUI

open class LowtechAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: Open

    @Atomic open var hotkeysRegistered = false
    @Atomic open var altHotkeysRegistered = false
    @Atomic open var shiftHotkeysRegistered = false
    @Atomic open var specialHotkeyRegistered = false
    @Atomic open var showPopoverOnSpecialKey = true

    open var initialized = false

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

        if Defaults[.launchCount] == 1, showPopoverOnFirstLaunch {
            mainAsyncAfter(ms: 3000) {
                guard let s = self.statusBar, !s.popover.isShown else { return }
                s.showPopover(self)
            }
        }
    }

    @objc open func onHotkey(_: String) {}
    @objc open func onAltHotkey(_: String) {}
    @objc open func onShiftHotkey(_: String) {}

    // MARK: Public

    public private(set) static var instance: LowtechAppDelegate!

    public var showPopoverOnFirstLaunch = true
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
    public var accentColor: Color?

    public lazy var specialKeyIdentifier = "SPECIAL_KEY\(specialKey)"

    public var normalKeys: [String] = []
    public var altKeys: [String] = []
    public var shiftKeys: [String] = []

    public lazy var altKeyModifiers: [TriggerKey] = {
        guard !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.option)
        else {
            return []
        }
        return normalKeyModifiers + [.ralt]
    }()

    public lazy var shiftKeyModifiers: [TriggerKey] = {
        guard !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.shift)
        else {
            return []
        }
        return normalKeyModifiers + [.rshift]
    }()

    public var hotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            oldValue.forEach { $0.unregister() }
        }
    }

    public var altHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            oldValue.forEach { $0.unregister() }
        }
    }

    public var shiftHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            oldValue.forEach { $0.unregister() }
        }
    }

    public var specialHotkey: HotKey? {
        didSet {
            guard initialized else { return }
            oldValue?.unregister()
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

    @Published public var normalKeyModifiers: [TriggerKey] = [] {
        didSet {
            reinitHotkeys()
        }
    }

    @Published public var specialKeyModifiers: [TriggerKey] = [.ralt] {
        didSet {
            reinitHotkeys()
        }
    }

    @Published public var specialKey = "" {
        didSet {
            reinitHotkeys()
        }
    }

    public func reinitHotkeys() {
        guard initialized else { return }
        unregisterHotkeys()
        unregisterAltHotkeys()
        unregisterShiftHotkeys()
        unregisterSpecialHotkey()
        computeKeyModifiers()
        specialKeyIdentifier = "SPECIAL_KEY\(specialKey)"
        initHotkeys()
    }

    public func computeKeyModifiers() {
        if !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.option) {
            altKeyModifiers = normalKeyModifiers + [.ralt]
        } else {
            altKeyModifiers = []
        }

        if !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.shift) {
            shiftKeyModifiers = normalKeyModifiers + [.rshift]
        } else {
            shiftKeyModifiers = []
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

    @objc public func handleSpecialHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard specialKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard showPopoverOnSpecialKey else {
            return
        }
        statusBar?.togglePopover(sender: self, at: .mouseLocation(centeredOn: statusBar?.window))
    }

    @objc public func handleHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard normalKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        onHotkey(hotkey.identifier)
    }

    @objc public func handleAltHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard altKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        onAltHotkey(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleShiftHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard shiftKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        onShiftHotkey(hotkey.identifier.suffix(1).s)
    }

    public func initHotkeys() {
        if !specialKey.isEmpty, !specialKeyModifiers.isEmpty {
            specialHotkey = HotKey(
                identifier: specialKeyIdentifier,
                keyCombo: KeyCombo(
                    key: .init(character: specialKey, virtualKeyCode: nil)!,
                    cocoaModifiers: specialKeyModifiers.sideIndependentModifiers
                )!,
                target: self,
                action: #selector(handleSpecialHotkey(_:)),
                actionQueue: .main,
                detectKeyHold: false
            )
        } else {
            specialHotkey = nil
        }

        if !normalKeys.isEmpty, !normalKeyModifiers.isEmpty {
            hotkeys = buildHotkeys(
                for: normalKeys,
                modifiers: normalKeyModifiers.sideIndependentModifiers,
                action: #selector(handleHotkey(_:)),
                detectKeyHold: false
            )
        } else {
            hotkeys = []
        }

        if !altKeys.isEmpty, !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.option) {
            altHotkeys = buildHotkeys(
                for: altKeys,
                modifiers: altKeyModifiers.sideIndependentModifiers,
                action: #selector(handleAltHotkey(_:)),
                identifier: "alt-",
                detectKeyHold: false
            )
        } else {
            altHotkeys = []
        }

        if !shiftKeys.isEmpty, !normalKeyModifiers.isEmpty, !normalKeyModifiers.sideIndependentModifiers.contains(.shift) {
            shiftHotkeys = buildHotkeys(
                for: shiftKeys,
                modifiers: shiftKeyModifiers.sideIndependentModifiers,
                action: #selector(handleShiftHotkey(_:)),
                identifier: "shift-",
                detectKeyHold: false
            )
        } else {
            shiftHotkeys = []
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

    public func onFlagsChanged(event: NSEvent) {
        rcmd = event.modifierFlags.contains(.rightCommand)
        ralt = event.modifierFlags.contains(.rightOption)
        rshift = event.modifierFlags.contains(.rightShift)
        rctrl = event.modifierFlags.contains(.rightControl)
        lcmd = (!event.modifierFlags.intersection([.leftCommand, .command]).isEmpty && !rcmd)
        lalt = (!event.modifierFlags.intersection([.leftOption, .option]).isEmpty && !ralt)
        lctrl = (!event.modifierFlags.intersection([.leftControl, .control]).isEmpty && !rctrl)
        lshift = (!event.modifierFlags.intersection([.leftShift, .shift]).isEmpty && !rshift)

        if specialKeyModifiers.allPressed {
            registerSpecialHotkey()
        } else {
            unregisterSpecialHotkey()
        }
        if normalKeyModifiers.allPressed {
            registerHotkeys()
        } else {
            unregisterHotkeys()
        }
        if altKeyModifiers.allPressed {
            registerAltHotkeys()
        } else {
            unregisterAltHotkeys()
        }
        if shiftKeyModifiers.allPressed {
            registerShiftHotkeys()
        } else {
            unregisterShiftHotkeys()
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
        detectKeyHold: Bool = false,
        ignoredKeys: Set<String>? = nil
    ) -> [HotKey] {
        var keys = Set(keys)
        if let ignoredKeys { keys.subtract(ignoredKeys) }

        return keys.map { ch in
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

    public func registerSpecialHotkey() {
        guard let specialHotkey, !specialHotkeyRegistered, !SWIFTUI_PREVIEW else { return }
        specialHotkey.register()
        specialHotkeyRegistered = true
    }

    public func unregisterSpecialHotkey() {
        guard let specialHotkey, specialHotkeyRegistered else { return }
        specialHotkey.unregister()
        specialHotkeyRegistered = false
    }

    public func registerHotkeys() {
        guard !hotkeys.isEmpty, !hotkeysRegistered, !SWIFTUI_PREVIEW else { return }
        hotkeys.forEach { $0.register() }
        hotkeysRegistered = true
    }

    public func unregisterHotkeys() {
        guard !hotkeys.isEmpty, hotkeysRegistered else { return }
        hotkeys.forEach { $0.unregister() }
        hotkeysRegistered = false
    }

    public func registerShiftHotkeys() {
        guard !shiftHotkeys.isEmpty, !shiftHotkeysRegistered, !shiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        shiftHotkeys.forEach { $0.register() }
        shiftHotkeysRegistered = true
    }

    public func unregisterShiftHotkeys() {
        guard !shiftHotkeys.isEmpty, shiftHotkeysRegistered else { return }
        shiftHotkeys.forEach { $0.unregister() }
        shiftHotkeysRegistered = false
    }

    public func registerAltHotkeys() {
        guard !altHotkeys.isEmpty, !altHotkeysRegistered, !altHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        altHotkeys.forEach { $0.register() }
        altHotkeysRegistered = true
    }

    public func unregisterAltHotkeys() {
        guard !altHotkeys.isEmpty, altHotkeysRegistered else { return }
        altHotkeys.forEach { $0.unregister() }
        altHotkeysRegistered = false
    }
}
