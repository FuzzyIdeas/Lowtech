import Cocoa
import Combine
import Defaults
import Foundation
import Magnet
import SwiftUI

open class LowtechAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: Open

    @Published open var primaryHotkeysRegistered = false
    @Published open var secondaryHotkeysRegistered = false
    @Published open var altHotkeysRegistered = false
    @Published open var shiftHotkeysRegistered = false
    @Published open var specialHotkeyRegistered = false
    @Published open var showPopoverOnSpecialKey = true

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

    @objc open func onPrimaryHotkey(_: String) {}
    @objc open func onSecondaryHotkey(_: String) {}
    @objc open func onAltHotkey(_: String) {}
    @objc open func onShiftHotkey(_: String) {}

    open func onFlagsChanged(event: NSEvent) {
        rcmd = event.modifierFlags.contains(.rightCommand)
        ralt = event.modifierFlags.contains(.rightOption)
        rshift = event.modifierFlags.contains(.rightShift)
        rctrl = event.modifierFlags.contains(.rightControl)
        lcmd = (!event.modifierFlags.intersection([.leftCommand, .command]).isEmpty && !rcmd)
        lalt = (!event.modifierFlags.intersection([.leftOption, .option]).isEmpty && !ralt)
        lctrl = (!event.modifierFlags.intersection([.leftControl, .control]).isEmpty && !rctrl)
        lshift = (!event.modifierFlags.intersection([.leftShift, .shift]).isEmpty && !rshift)
        fn = event.modifierFlags.contains(.fn)

        if specialKeyModifiers.allPressed {
            registerSpecialHotkey()
        } else {
            unregisterSpecialHotkey()
        }
        if primaryKeyModifiers.allPressed {
            registerPrimaryHotkeys()
        } else {
            unregisterPrimaryHotkeys()
        }
        if secondaryKeyModifiers.allPressed {
            registerSecondaryHotkeys()
        } else {
            unregisterSecondaryHotkeys()
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

    open func registerSpecialHotkey() {
        guard let specialHotkey, !specialHotkeyRegistered, !SWIFTUI_PREVIEW else { return }
        specialHotkey.register()
        specialHotkeyRegistered = true
    }

    open func unregisterSpecialHotkey() {
        guard let specialHotkey, specialHotkeyRegistered else { return }
        specialHotkey.unregister()
        specialHotkeyRegistered = false
    }

    open func registerPrimaryHotkeys() {
        guard !primaryHotkeys.isEmpty, !primaryHotkeysRegistered, !SWIFTUI_PREVIEW else { return }
        primaryHotkeys.forEach { $0.register() }
        primaryHotkeysRegistered = true
    }

    open func unregisterPrimaryHotkeys() {
        guard !primaryHotkeys.isEmpty, primaryHotkeysRegistered else { return }
        primaryHotkeys.forEach { $0.unregister() }
        primaryHotkeysRegistered = false
    }

    open func registerSecondaryHotkeys() {
        guard !secondaryHotkeys.isEmpty, !secondaryHotkeysRegistered, !SWIFTUI_PREVIEW else { return }
        secondaryHotkeys.forEach { $0.register() }
        secondaryHotkeysRegistered = true
    }

    open func unregisterSecondaryHotkeys() {
        guard !secondaryHotkeys.isEmpty, secondaryHotkeysRegistered else { return }
        secondaryHotkeys.forEach { $0.unregister() }
        secondaryHotkeysRegistered = false
    }

    open func registerShiftHotkeys() {
        guard !shiftHotkeys.isEmpty, !shiftHotkeysRegistered, !shiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        shiftHotkeys.forEach { $0.register() }
        shiftHotkeysRegistered = true
    }

    open func unregisterShiftHotkeys() {
        guard !shiftHotkeys.isEmpty, shiftHotkeysRegistered else { return }
        shiftHotkeys.forEach { $0.unregister() }
        shiftHotkeysRegistered = false
    }

    open func registerAltHotkeys() {
        guard !altHotkeys.isEmpty, !altHotkeysRegistered, !altHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        altHotkeys.forEach { $0.register() }
        altHotkeysRegistered = true
    }

    open func unregisterAltHotkeys() {
        guard !altHotkeys.isEmpty, altHotkeysRegistered else { return }
        altHotkeys.forEach { $0.unregister() }
        altHotkeysRegistered = false
    }

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

    public var primaryKeys: [String] = []
    public var secondaryKeys: [String] = []
    public var altKeys: [String] = []
    public var shiftKeys: [String] = []

    public lazy var altKeyModifiers: [TriggerKey] = {
        guard !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.option)
        else {
            return []
        }
        return primaryKeyModifiers + [.ralt]
    }()

    public lazy var shiftKeyModifiers: [TriggerKey] = {
        guard !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift)
        else {
            return []
        }
        return primaryKeyModifiers + [.rshift]
    }()

    public var primaryHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            oldValue.forEach { $0.unregister() }
        }
    }

    public var secondaryHotkeys: [HotKey] = [] {
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

    @Published public var primaryKeyModifiers: [TriggerKey] = [] {
        didSet {
            reinitHotkeys()
        }
    }

    @Published public var secondaryKeyModifiers: [TriggerKey] = [] {
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
        unregisterPrimaryHotkeys()
        unregisterSecondaryHotkeys()
        unregisterAltHotkeys()
        unregisterShiftHotkeys()
        unregisterSpecialHotkey()
        computeKeyModifiers()
        specialKeyIdentifier = "SPECIAL_KEY\(specialKey)"
        initHotkeys()
    }

    public func computeKeyModifiers() {
        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            altKeyModifiers = primaryKeyModifiers + [.ralt]
        } else {
            altKeyModifiers = []
        }

        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            shiftKeyModifiers = primaryKeyModifiers + [.rshift]
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

    @objc public func handlePrimaryHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard primaryKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        onPrimaryHotkey(hotkey.identifier)
    }

    @objc public func handleSecondaryHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard secondaryKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        onSecondaryHotkey(hotkey.identifier.suffix(1).s)
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
        initSpecialHotkeys()
        initPrimaryHotkeys()
        initSecondaryHotkeys()
        initAltHotkeys()
        initShiftHotkeys()
    }

    public func initSpecialHotkeys() {
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
    }

    public func initPrimaryHotkeys() {
        if !primaryKeys.isEmpty, !primaryKeyModifiers.isEmpty {
            primaryHotkeys = buildHotkeys(
                for: primaryKeys,
                modifiers: primaryKeyModifiers.sideIndependentModifiers,
                action: #selector(handlePrimaryHotkey(_:)),
                detectKeyHold: false
            )
        } else {
            primaryHotkeys = []
        }
    }

    public func initSecondaryHotkeys() {
        if !secondaryKeys.isEmpty, !secondaryKeyModifiers.isEmpty {
            secondaryHotkeys = buildHotkeys(
                for: secondaryKeys,
                modifiers: secondaryKeyModifiers.sideIndependentModifiers,
                action: #selector(handleSecondaryHotkey(_:)),
                identifier: "secondary-",
                detectKeyHold: false
            )
        } else {
            secondaryHotkeys = []
        }
    }

    public func initAltHotkeys() {
        if !altKeys.isEmpty, !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.option) {
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
    }

    public func initShiftHotkeys() {
        if !shiftKeys.isEmpty, !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
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
}
