//
//  Keys.swift
//
//
//  Created by Alin Panaitiu on 21.01.2022.
//

import Combine
import Defaults
import Foundation
import Magnet
import Sauce
import SwiftUI

// MARK: - KeysManager

public class KeysManager: ObservableObject {
    init() {
        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            altKeyModifiers = primaryKeyModifiers + [.alt]
        }

        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            rightShiftKeyModifiers = primaryKeyModifiers + [.rshift]
            leftShiftKeyModifiers = primaryKeyModifiers + [.lshift]
        }

        if !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            secondaryAltKeyModifiers = secondaryKeyModifiers + [.ralt]
        }

        if !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            secondaryRightShiftKeyModifiers = secondaryKeyModifiers + [.rshift]
            secondaryLeftShiftKeyModifiers = secondaryKeyModifiers + [.lshift]
        }

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { notification in
                self.recheckFlags()
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: .SauceSelectedKeyboardKeyCodesChanged)
            .sink { [self] _ in
                Set<CGKeyCode>.NUMBER_KEYS = Set([
                    SauceKey.zero, SauceKey.one, SauceKey.two, SauceKey.three, SauceKey.four, SauceKey.five, SauceKey.six, SauceKey.seven, SauceKey.eight, SauceKey.nine,
                ].map { Sauce.shared.keyCode(for: $0) })
                Set<CGKeyCode>.FUNCTION_KEYS = Set([
                    SauceKey.f1, SauceKey.f2, SauceKey.f3, SauceKey.f4, SauceKey.f5, SauceKey.f6, SauceKey.f7, SauceKey.f8, SauceKey.f9, SauceKey.f10, SauceKey.f11, SauceKey.f12,
                    SauceKey.f13, SauceKey.f14, SauceKey.f15, SauceKey.f16, SauceKey.f17, SauceKey.f18, SauceKey.f19, SauceKey.f20,
                ].map { Sauce.shared.keyCode(for: $0) })
                Set<CGKeyCode>.ALPHANUMERIC_KEYS = Set([
                    SauceKey.zero, SauceKey.one, SauceKey.two, SauceKey.three, SauceKey.four, SauceKey.five, SauceKey.six, SauceKey.seven, SauceKey.eight, SauceKey.nine,
                    SauceKey.q, SauceKey.w, SauceKey.e, SauceKey.r, SauceKey.t, SauceKey.y, SauceKey.u, SauceKey.i, SauceKey.o, SauceKey.p,
                    SauceKey.a, SauceKey.s, SauceKey.d, SauceKey.f, SauceKey.g, SauceKey.h, SauceKey.j, SauceKey.k, SauceKey.l,
                    SauceKey.z, SauceKey.x, SauceKey.c, SauceKey.v, SauceKey.b, SauceKey.n, SauceKey.m,
                ].map { Sauce.shared.keyCode(for: $0) })

                Set<CGKeyCode>.SYMBOL_KEYS = Set([
                    SauceKey.equal, SauceKey.minus, SauceKey.rightBracket, SauceKey.leftBracket,
                    SauceKey.quote, SauceKey.semicolon, SauceKey.backslash, SauceKey.section,
                    SauceKey.comma, SauceKey.slash, SauceKey.period, SauceKey.grave,
                ].map { Sauce.shared.keyCode(for: $0) })

                Set<CGKeyCode>.ALPHA_KEYS = Set<CGKeyCode>.ALPHANUMERIC_KEYS.subtracting(Set<CGKeyCode>.NUMBER_KEYS)
                Set<CGKeyCode>.ALL_KEYS = Set<CGKeyCode>.FUNCTION_KEYS.union(Set<CGKeyCode>.NUMBER_KEYS).union(Set<CGKeyCode>.ALPHANUMERIC_KEYS).union(Set<CGKeyCode>.SYMBOL_KEYS)

                Set<Int>.NUMBER_KEYS = Set(Set<CGKeyCode>.NUMBER_KEYS.map { Int($0) })
                Set<Int>.FUNCTION_KEYS = Set(Set<CGKeyCode>.FUNCTION_KEYS.map { Int($0) })
                Set<Int>.ALPHANUMERIC_KEYS = Set(Set<CGKeyCode>.ALPHANUMERIC_KEYS.map { Int($0) })
                Set<Int>.SYMBOL_KEYS = Set(Set<CGKeyCode>.SYMBOL_KEYS.map { Int($0) })
                Set<Int>.ALPHA_KEYS = Set(Set<CGKeyCode>.ALPHA_KEYS.map { Int($0) })
                Set<Int>.ALL_KEYS = Set(Set<CGKeyCode>.ALL_KEYS.map { Int($0) })

                if keepSpecialKeyPosition, let specialKeyCode {
                    specialKey = Sauce.shared.key(for: specialKeyCode.i)
                }

                reinitHotkeys()
            }.store(in: &observers)
    }

    @Published open var primaryHotkeysRegistered = false
    @Published open var secondaryHotkeysRegistered = false

    @Published open var altHotkeysRegistered = false
    @Published open var rightShiftHotkeysRegistered = false
    @Published open var leftShiftHotkeysRegistered = false

    @Published open var secondaryAltHotkeysRegistered = false
    @Published open var secondaryRightShiftHotkeysRegistered = false
    @Published open var secondaryLeftShiftHotkeysRegistered = false

    @Published open var specialHotkeyRegistered = false

    open var initialized = false {
        didSet {
            guard initialized else { return }
            computeKeyModifiers()
        }
    }

    open func flagsChanged(modifierFlags: NSEvent.ModifierFlags) {
        KM.lastModifierFlags = modifierFlags

        KM.rcmd = modifierFlags.contains(.rightCommand)
        KM.ralt = modifierFlags.contains(.rightOption)
        KM.rshift = modifierFlags.contains(.rightShift)
        KM.rctrl = modifierFlags.contains(.rightControl)

        KM.lcmd = modifierFlags.contains(.leftCommand) || (modifierFlags.contains(.command) && !modifierFlags.contains(.rightCommand))
        KM.lalt = modifierFlags.contains(.leftOption) || (modifierFlags.contains(.option) && !modifierFlags.contains(.rightOption))
        KM.lshift = modifierFlags.contains(.leftShift) || (modifierFlags.contains(.shift) && !modifierFlags.contains(.rightShift))
        KM.lctrl = modifierFlags.contains(.leftControl) || (modifierFlags.contains(.control) && !modifierFlags.contains(.rightControl))

        KM.fn = modifierFlags.contains(.fn)
        KM.flags = modifierFlags.triggerKeys

        if testKeyCombo == nil || testKeyCombo!.key != specialKey {
            if specialKeyModifiers.allPressedExclusive {
                registerSpecialHotkey()
            } else {
                unregisterSpecialHotkey()
            }
        }

        if primaryKeyModifiers.allPressedExclusive {
            registerPrimaryHotkeys()
        } else {
            unregisterPrimaryHotkeys()
        }
        if secondaryKeyModifiers.allPressedExclusive {
            registerSecondaryHotkeys()
        } else {
            unregisterSecondaryHotkeys()
        }
        if altKeyModifiers.allPressedExclusive {
            registerAltHotkeys()
        } else {
            unregisterAltHotkeys()
        }
        if rightShiftKeyModifiers.allPressedExclusive {
            registerRightShiftHotkeys()
        } else {
            unregisterRightShiftHotkeys()
        }
        if leftShiftKeyModifiers.allPressedExclusive {
            registerLeftShiftHotkeys()
        } else {
            unregisterLeftShiftHotkeys()
        }

        if secondaryAltKeyModifiers.allPressedExclusive {
            registerSecondaryAltHotkeys()
        } else {
            unregisterSecondaryAltHotkeys()
        }
        if secondaryRightShiftKeyModifiers.allPressedExclusive {
            registerSecondaryRightShiftHotkeys()
        } else {
            unregisterSecondaryRightShiftHotkeys()
        }
        if secondaryLeftShiftKeyModifiers.allPressedExclusive {
            registerSecondaryLeftShiftHotkeys()
        } else {
            unregisterSecondaryLeftShiftHotkeys()
        }

        guard !KM.flags.isEmpty else { return }
        if let taps = KM.multiTap[KM.flags], let tapTime = KM.multiTapTime[KM.flags], timeSince(tapTime) <= KeysManager.MULTI_TAP_THRESHOLD_INTERVAL {
            KM.multiTap[KM.flags] = taps + 1
            KM.multiTapPublisher.send((KM.flags, taps + 1))
        } else {
            KM.multiTap[KM.flags] = 1
            KM.multiTapPublisher.send((KM.flags, 1))
        }
        KM.multiTapTime[KM.flags] = Date()

        onFlagsChanged?(modifierFlags)
    }

    open func registerSpecialHotkey() {
        onRegisterSpecialHotkey?()

        guard let specialHotkey, !specialHotkeyRegistered, !SWIFTUI_PREVIEW else { return }
        specialHotkey.register()
        specialHotkeyRegistered = true
    }

    open func unregisterSpecialHotkey() {
        onUnregisterSpecialHotkey?()

        guard let specialHotkey, specialHotkeyRegistered else { return }
        specialHotkey.unregister()
        specialHotkeyRegistered = false
    }

    open func registerPrimaryHotkeys() {
        onRegisterPrimaryHotkeys?()

        guard !primaryHotkeys.isEmpty, !primaryHotkeysRegistered, !SWIFTUI_PREVIEW else { return }
        debug("registerPrimaryHotkeys")
        for key in primaryHotkeys {
            key.register()
        }
        primaryHotkeysRegistered = true
    }

    open func unregisterPrimaryHotkeys() {
        onUnregisterPrimaryHotkeys?()

        guard !primaryHotkeys.isEmpty, primaryHotkeysRegistered else { return }
        debug("unregisterPrimaryHotkeys")
        for key in primaryHotkeys {
            key.unregister()
        }
        primaryHotkeysRegistered = false
    }

    open func registerSecondaryHotkeys() {
        onRegisterSecondaryHotkeys?()

        guard !secondaryHotkeys.isEmpty, !secondaryHotkeysRegistered, !SWIFTUI_PREVIEW else { return }
        for key in secondaryHotkeys {
            key.register()
        }
        secondaryHotkeysRegistered = true
    }

    open func unregisterSecondaryHotkeys() {
        onUnregisterSecondaryHotkeys?()

        guard !secondaryHotkeys.isEmpty, secondaryHotkeysRegistered else { return }
        for key in secondaryHotkeys {
            key.unregister()
        }
        secondaryHotkeysRegistered = false
    }

    open func registerRightShiftHotkeys() {
        onRegisterRightShiftHotkeys?()

        guard !rightShiftHotkeys.isEmpty, !rightShiftHotkeysRegistered, !rightShiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in rightShiftHotkeys {
            key.register()
        }
        rightShiftHotkeysRegistered = true
    }

    open func unregisterRightShiftHotkeys() {
        onUnregisterRightShiftHotkeys?()

        guard !rightShiftHotkeys.isEmpty, rightShiftHotkeysRegistered else { return }
        for key in rightShiftHotkeys {
            key.unregister()
        }
        rightShiftHotkeysRegistered = false
    }

    open func registerLeftShiftHotkeys() {
        onRegisterLeftShiftHotkeys?()

        guard !leftShiftHotkeys.isEmpty, !leftShiftHotkeysRegistered, !leftShiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in leftShiftHotkeys {
            key.register()
        }
        leftShiftHotkeysRegistered = true
    }

    open func unregisterLeftShiftHotkeys() {
        onUnregisterLeftShiftHotkeys?()

        guard !leftShiftHotkeys.isEmpty, leftShiftHotkeysRegistered else { return }
        for key in leftShiftHotkeys {
            key.unregister()
        }
        leftShiftHotkeysRegistered = false
    }

    open func registerAltHotkeys() {
        onRegisterAltHotkeys?()

        guard !altHotkeys.isEmpty, !altHotkeysRegistered, !altHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in altHotkeys {
            key.register()
        }
        altHotkeysRegistered = true
    }

    open func unregisterAltHotkeys() {
        onUnregisterAltHotkeys?()

        guard !altHotkeys.isEmpty, altHotkeysRegistered else { return }
        for key in altHotkeys {
            key.unregister()
        }
        altHotkeysRegistered = false
    }

    open func registerSecondaryRightShiftHotkeys() {
        onRegisterSecondaryRightShiftHotkeys?()

        guard !secondaryRightShiftHotkeys.isEmpty, !secondaryRightShiftHotkeysRegistered, !secondaryRightShiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in secondaryRightShiftHotkeys {
            key.register()
        }
        secondaryRightShiftHotkeysRegistered = true
    }

    open func unregisterSecondaryRightShiftHotkeys() {
        onUnregisterSecondaryRightShiftHotkeys?()

        guard !secondaryRightShiftHotkeys.isEmpty, secondaryRightShiftHotkeysRegistered else { return }
        for key in secondaryRightShiftHotkeys {
            key.unregister()
        }
        secondaryRightShiftHotkeysRegistered = false
    }

    open func registerSecondaryLeftShiftHotkeys() {
        onRegisterSecondaryLeftShiftHotkeys?()

        guard !secondaryLeftShiftHotkeys.isEmpty, !secondaryLeftShiftHotkeysRegistered, !secondaryLeftShiftHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in secondaryLeftShiftHotkeys {
            key.register()
        }
        secondaryLeftShiftHotkeysRegistered = true
    }

    open func unregisterSecondaryLeftShiftHotkeys() {
        onUnregisterSecondaryLeftShiftHotkeys?()

        guard !secondaryLeftShiftHotkeys.isEmpty, secondaryLeftShiftHotkeysRegistered else { return }
        for key in secondaryLeftShiftHotkeys {
            key.unregister()
        }
        secondaryLeftShiftHotkeysRegistered = false
    }

    open func registerSecondaryAltHotkeys() {
        onRegisterSecondaryAltHotkeys?()

        guard !secondaryAltHotkeys.isEmpty, !secondaryAltHotkeysRegistered, !secondaryAltHotkeys.isEmpty, !SWIFTUI_PREVIEW else { return }
        for key in secondaryAltHotkeys {
            key.register()
        }
        secondaryAltHotkeysRegistered = true
    }

    open func unregisterSecondaryAltHotkeys() {
        onUnregisterSecondaryAltHotkeys?()

        guard !secondaryAltHotkeys.isEmpty, secondaryAltHotkeysRegistered else { return }
        for key in secondaryAltHotkeys {
            key.unregister()
        }
        secondaryAltHotkeysRegistered = false
    }

    public var onFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?
    public var onSpecialHotkey: (() -> Void)?
    public var onPrimaryHotkey: ((String) -> Void)?
    public var onSecondaryHotkey: ((String) -> Void)?

    public var onAltHotkey: ((String) -> Void)?
    public var onRightShiftHotkey: ((String) -> Void)?
    public var onLeftShiftHotkey: ((String) -> Void)?

    public var onSecondaryAltHotkey: ((String) -> Void)?
    public var onSecondaryRightShiftHotkey: ((String) -> Void)?
    public var onSecondaryLeftShiftHotkey: ((String) -> Void)?

    public var onRegisterSpecialHotkey: (() -> Void)?
    public var onUnregisterSpecialHotkey: (() -> Void)?
    public var onRegisterPrimaryHotkeys: (() -> Void)?
    public var onUnregisterPrimaryHotkeys: (() -> Void)?
    public var onRegisterSecondaryHotkeys: (() -> Void)?
    public var onUnregisterSecondaryHotkeys: (() -> Void)?

    public var onRegisterRightShiftHotkeys: (() -> Void)?
    public var onUnregisterRightShiftHotkeys: (() -> Void)?
    public var onRegisterLeftShiftHotkeys: (() -> Void)?
    public var onUnregisterLeftShiftHotkeys: (() -> Void)?
    public var onRegisterAltHotkeys: (() -> Void)?
    public var onUnregisterAltHotkeys: (() -> Void)?

    public var onRegisterSecondaryRightShiftHotkeys: (() -> Void)?
    public var onUnregisterSecondaryRightShiftHotkeys: (() -> Void)?
    public var onRegisterSecondaryLeftShiftHotkeys: (() -> Void)?
    public var onUnregisterSecondaryLeftShiftHotkeys: (() -> Void)?
    public var onRegisterSecondaryAltHotkeys: (() -> Void)?
    public var onUnregisterSecondaryAltHotkeys: (() -> Void)?

    @Published public var rcmd = false
    @Published public var ralt = false
    @Published public var rshift = false
    @Published public var rctrl = false
    @Published public var lcmd = false
    @Published public var lalt = false
    @Published public var lctrl = false
    @Published public var lshift = false
    @Published public var fn = false
    @Published public var flags = [TriggerKey]()
    @Published public var lastModifierFlags: NSEvent.ModifierFlags = NSEvent.modifierFlags

    @Published public var testKeyHandler: (() -> Void)? = nil
    @Published public var testKeyCombo: KeyCombo? = nil
    @Published public var testKeyPressed = false
    @Published public var testKeyForward = false

    @Published public var multiTap = [[TriggerKey]: Int]()
    @Published public var multiTapTime = [[TriggerKey]: Date]()
    public var multiTapPublisher = PassthroughSubject<([TriggerKey], Int), Never>()

    public lazy var specialKeyIdentifier = "SPECIAL_KEY-\(specialKey?.character ?? "NO_KEY")"

    public var primaryKeys: [String] = []
    public var secondaryKeys: [String] = []

    public var altKeys: [String] = []
    public var rightShiftKeys: [String] = []
    public var leftShiftKeys: [String] = []

    public var secondaryAltKeys: [String] = []
    public var secondaryRightShiftKeys: [String] = []
    public var secondaryLeftShiftKeys: [String] = []

    public var globalEventMonitor: GlobalEventMonitor!
    public var localEventMonitor: LocalEventMonitor!
    public var observers: Set<AnyCancellable> = []

    @Published public var disabledAltKeys = false
    @Published public var disabledRightShiftKeys = false
    @Published public var disabledLeftShiftKeys = false

    @Published public var disabledSecondaryAltKeys = false
    @Published public var disabledSecondaryRightShiftKeys = false
    @Published public var disabledSecondaryLeftShiftKeys = false

    public lazy var specialKeyCode: CGKeyCode? = specialKey?.QWERTYKeyCode

    public var keepSpecialKeyPosition = false

    @Published public var testHotkey: HotKey? = nil {
        didSet {
            if let testHotkey, oldValue == nil {
                testHotkey.register()
            }
            if let oldValue, testHotkey == nil {
                oldValue.unregister()
            }
        }
    }

    @Published public var altKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledAltKeys = altKeyModifiers.isEmpty
        }
    }

    @Published public var rightShiftKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledRightShiftKeys = rightShiftKeyModifiers.isEmpty
        }
    }

    @Published public var leftShiftKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledLeftShiftKeys = leftShiftKeyModifiers.isEmpty
        }
    }

    @Published public var secondaryAltKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledSecondaryAltKeys = secondaryAltKeyModifiers.isEmpty
        }
    }

    @Published public var secondaryRightShiftKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledSecondaryRightShiftKeys = secondaryRightShiftKeyModifiers.isEmpty
        }
    }

    @Published public var secondaryLeftShiftKeyModifiers: [TriggerKey] = [] {
        didSet {
            disabledSecondaryLeftShiftKeys = secondaryLeftShiftKeyModifiers.isEmpty
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

    @Published public var specialKeyModifiers: [TriggerKey] = [.ralt, .rshift] {
        didSet {
            reinitHotkeys()
        }
    }

    @Published public var specialKey: SauceKey? = nil {
        didSet {
            reinitHotkeys()
        }
    }

    public var primaryHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var secondaryHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var altHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var rightShiftHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var leftShiftHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var secondaryAltHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var secondaryRightShiftHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var secondaryLeftShiftHotkeys: [HotKey] = [] {
        didSet {
            guard initialized else { return }
            for key in oldValue {
                key.unregister()
            }
        }
    }

    public var specialHotkey: HotKey? {
        didSet {
            guard initialized else { return }
            oldValue?.unregister()
        }
    }

    public func reinitHotkeys() {
        guard initialized else { return }
        unregisterPrimaryHotkeys()
        unregisterSecondaryHotkeys()

        unregisterAltHotkeys()
        unregisterRightShiftHotkeys()
        unregisterLeftShiftHotkeys()

        unregisterSecondaryAltHotkeys()
        unregisterSecondaryRightShiftHotkeys()
        unregisterSecondaryLeftShiftHotkeys()

        unregisterSpecialHotkey()
        computeKeyModifiers()
        specialKeyIdentifier = "SPECIAL_KEY-\(specialKey?.character ?? "NO_KEY")"
        initHotkeys()
    }

    public func computeKeyModifiers() {
        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            altKeyModifiers = primaryKeyModifiers + [.alt]
        } else {
            altKeyModifiers = []
        }

        if !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            rightShiftKeyModifiers = primaryKeyModifiers + [.rshift]
            leftShiftKeyModifiers = primaryKeyModifiers + [.lshift]
        } else {
            rightShiftKeyModifiers = []
            leftShiftKeyModifiers = []
        }

        if !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            secondaryAltKeyModifiers = secondaryKeyModifiers + [.ralt]
        } else {
            secondaryAltKeyModifiers = []
        }

        if !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            secondaryRightShiftKeyModifiers = secondaryKeyModifiers + [.rshift]
            secondaryLeftShiftKeyModifiers = secondaryKeyModifiers + [.lshift]
        } else {
            secondaryRightShiftKeyModifiers = []
            secondaryLeftShiftKeyModifiers = []
        }
    }

    public func initHotkeys() {
        initSpecialHotkeys()
        initPrimaryHotkeys()
        initSecondaryHotkeys()

        initAltHotkeys()
        initRightShiftHotkeys()
        initLeftShiftHotkeys()

        initSecondaryAltHotkeys()
        initSecondaryRightShiftHotkeys()
        initSecondaryLeftShiftHotkeys()
    }

    public func initSpecialHotkeys() {
        if let specialKey, !specialKeyModifiers.isEmpty, let combo = KeyCombo(
            key: specialKey,
            cocoaModifiers: specialKeyModifiers.sideIndependentModifiers
        ) {
            specialHotkey = HotKey(
                identifier: specialKeyIdentifier,
                keyCombo: combo,
                actionQueue: .main,
                detectKeyHold: false,
                handler: handleSpecialHotkey
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
                detectKeyHold: false,
                action: handlePrimaryHotkey
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
                identifier: "secondary-",
                detectKeyHold: false,
                action: handleSecondaryHotkey
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
                identifier: "alt-",
                detectKeyHold: false,
                action: handleAltHotkey
            )
        } else {
            altHotkeys = []
        }
    }

    public func initRightShiftHotkeys() {
        if !rightShiftKeys.isEmpty, !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            rightShiftHotkeys = buildHotkeys(
                for: rightShiftKeys,
                modifiers: rightShiftKeyModifiers.sideIndependentModifiers,
                identifier: "rshift-",
                detectKeyHold: false,
                action: handleRightShiftHotkey
            )
        } else {
            rightShiftHotkeys = []
        }
    }

    public func initLeftShiftHotkeys() {
        if !leftShiftKeys.isEmpty, !primaryKeyModifiers.isEmpty, !primaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            leftShiftHotkeys = buildHotkeys(
                for: leftShiftKeys,
                modifiers: leftShiftKeyModifiers.sideIndependentModifiers,
                identifier: "lshift-",
                detectKeyHold: false,
                action: handleLeftShiftHotkey
            )
        } else {
            leftShiftHotkeys = []
        }
    }

    public func initSecondaryAltHotkeys() {
        if !secondaryAltKeys.isEmpty, !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.option) {
            secondaryAltHotkeys = buildHotkeys(
                for: secondaryAltKeys,
                modifiers: secondaryAltKeyModifiers.sideIndependentModifiers,
                identifier: "secondary-alt-",
                detectKeyHold: false,
                action: handleSecondaryAltHotkey
            )
        } else {
            secondaryAltHotkeys = []
        }
    }

    public func initSecondaryRightShiftHotkeys() {
        if !secondaryRightShiftKeys.isEmpty, !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            secondaryRightShiftHotkeys = buildHotkeys(
                for: secondaryRightShiftKeys,
                modifiers: secondaryRightShiftKeyModifiers.sideIndependentModifiers,
                identifier: "secondary-rshift-",
                detectKeyHold: false,
                action: handleSecondaryRightShiftHotkey
            )
        } else {
            secondaryRightShiftHotkeys = []
        }
    }

    public func initSecondaryLeftShiftHotkeys() {
        if !secondaryLeftShiftKeys.isEmpty, !secondaryKeyModifiers.isEmpty, !secondaryKeyModifiers.sideIndependentModifiers.contains(.shift) {
            secondaryLeftShiftHotkeys = buildHotkeys(
                for: secondaryLeftShiftKeys,
                modifiers: secondaryLeftShiftKeyModifiers.sideIndependentModifiers,
                identifier: "secondary-lshift-",
                detectKeyHold: false,
                action: handleSecondaryLeftShiftHotkey
            )
        } else {
            secondaryLeftShiftHotkeys = []
        }
    }

    @MainActor
    public func initFlagsListener() {
        globalEventMonitor = GlobalEventMonitor(mask: .flagsChanged) { [self] event in
            guard let event else { return }
            flagsChanged(modifierFlags: event.modifierFlags.filterUnsupportedModifiers())
        }
        globalEventMonitor.start()

        localEventMonitor = LocalEventMonitor(mask: .flagsChanged) { [self] event in
            flagsChanged(modifierFlags: event.modifierFlags.filterUnsupportedModifiers())
            return event
        }
        localEventMonitor.start()
    }

    public func buildHotkeys(
        for keys: [String],
        modifiers: NSEvent.ModifierFlags,
        identifier: String = "",
        detectKeyHold: Bool = false,
        ignoredKeys: Set<String>? = nil,
        action: @escaping (HotKey) -> Void
    ) -> [HotKey] {
        guard modifiers.isNotEmpty else { return [] }

        var keys = Set(keys)
        if let ignoredKeys { keys.subtract(ignoredKeys) }

        return keys.compactMap { ch in
            guard let key = Key(character: ch, virtualKeyCode: nil), let combo = KeyCombo(key: key, cocoaModifiers: modifiers)
            else { return nil }

            return HotKey(
                identifier: "\(identifier)\(ch)",
                keyCombo: combo,
                actionQueue: .main,
                detectKeyHold: detectKeyHold,
                handler: action
            )
        }
    }

    @objc public func testKeyComboPressedShouldStop(hotkey: HotKey) -> Bool {
        guard let combo = KM.testKeyCombo, hotkey.keyCombo == combo else {
            return false
        }
        KM.testKeyPressed = true

        KM.testKeyHandler?()
        KM.testKeyHandler = nil

        return !KM.testKeyForward
    }

    @objc public func handleSpecialHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard specialKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onSpecialHotkey?()
    }

    @objc public func handlePrimaryHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard primaryKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onPrimaryHotkey?(hotkey.identifier)
    }

    @objc public func handleSecondaryHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard secondaryKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onSecondaryHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleAltHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard altKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onAltHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleRightShiftHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard rightShiftKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onRightShiftHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleLeftShiftHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard leftShiftKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onLeftShiftHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleSecondaryAltHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard secondaryAltKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onSecondaryAltHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleSecondaryRightShiftHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard secondaryRightShiftKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onSecondaryRightShiftHotkey?(hotkey.identifier.suffix(1).s)
    }

    @objc public func handleSecondaryLeftShiftHotkey(_ hotkey: HotKey) {
        #if DEBUG
            print(hotkey.identifier)
        #endif
        guard secondaryLeftShiftKeyModifiers.allPressed else {
            hotkey.forwardNextEvent = true
            return
        }

        guard !testKeyComboPressedShouldStop(hotkey: hotkey) else { return }
        onSecondaryLeftShiftHotkey?(hotkey.identifier.suffix(1).s)
    }

    static var MULTI_TAP_THRESHOLD_INTERVAL: TimeInterval = 0.4

    func recheckFlags() {
        guard lastModifierFlags.isNotEmpty else { return }

        let flags = NSEvent.modifierFlags.filterUnsupportedModifiers()
        if flags.isEmpty || !lastModifierFlags.contains(flags) {
            flagsChanged(modifierFlags: flags)
        }
    }
}

public let KM = KeysManager()

#if os(macOS)
    import Cocoa

    public enum TriggerKey: Int, Codable, Defaults.Serializable, Comparable, Identifiable {
        case lshift
        case lctrl
        case lalt
        case lcmd
        case rcmd
        case ralt
        case rctrl
        case rshift

        case cmd
        case alt
        case ctrl
        case shift

        public var id: Int { rawValue }
        public var modifier: NSEvent.ModifierFlags {
            switch self {
            case .rcmd:
                .rightCommand
            case .ralt:
                .rightOption
            case .lcmd:
                .leftCommand
            case .lalt:
                .leftOption
            case .lctrl:
                .leftControl
            case .lshift:
                .leftShift
            case .rshift:
                .rightShift
            case .rctrl:
                .rightControl
            case .cmd:
                .command
            case .alt:
                .option
            case .ctrl:
                .control
            case .shift:
                .shift
            }
        }

        public var sideIndependentModifier: NSEvent.ModifierFlags {
            switch self {
            case .rcmd, .lcmd, .cmd:
                .command
            case .ralt, .lalt, .alt:
                .option
            case .lctrl, .rctrl, .ctrl:
                .control
            case .rshift, .lshift, .shift:
                .shift
            }
        }

        public var directionalStr: String {
            switch self {
            case .rcmd:
                "⌘⃗"
            case .ralt:
                "⌥⃗"
            case .lcmd:
                "⌘⃖"
            case .lalt:
                "⌥⃖"
            case .lctrl:
                "^⃖"
            case .lshift:
                "⇧⃖"
            case .rshift:
                "⇧⃗"
            case .rctrl:
                "^⃗"
            case .cmd:
                "⌘"
            case .alt:
                "⌥"
            case .ctrl:
                "^"
            case .shift:
                "⇧"
            }
        }

        public var str: String {
            switch self {
            case .rcmd:
                "⌘"
            case .ralt:
                "⌥"
            case .lcmd:
                "⌘"
            case .lalt:
                "⌥"
            case .lctrl:
                "^"
            case .lshift:
                "⇧"
            case .rshift:
                "⇧"
            case .rctrl:
                "^"
            case .cmd:
                "⌘"
            case .alt:
                "⌥"
            case .ctrl:
                "^"
            case .shift:
                "⇧"
            }
        }

        public var readableStr: String {
            switch self {
            case .rcmd:
                "Right Command"
            case .ralt:
                "Right Option"
            case .lcmd:
                "Left Command"
            case .lalt:
                "Left Option"
            case .lctrl:
                "Left Control"
            case .lshift:
                "Left Shift"
            case .rshift:
                "Right Shift"
            case .rctrl:
                "Right Control"
            case .cmd:
                "Command"
            case .alt:
                "Option"
            case .ctrl:
                "Control"
            case .shift:
                "Shift"
            }
        }

        public var sideIndependentReadableStr: String {
            switch self {
            case .rcmd, .lcmd, .cmd:
                "Command"
            case .ralt, .lalt, .alt:
                "Option"
            case .lctrl, .rctrl, .ctrl:
                "Control"
            case .lshift, .rshift, .shift:
                "Shift"
            }
        }

        public var shortReadableStr: String {
            switch self {
            case .rcmd:
                "rcmd"
            case .ralt:
                "ralt"
            case .lcmd:
                "lcmd"
            case .lalt:
                "lalt"
            case .lctrl:
                "lctrl"
            case .lshift:
                "lshift"
            case .rshift:
                "rshift"
            case .rctrl:
                "rctrl"
            case .cmd:
                "cmd"
            case .alt:
                "alt"
            case .ctrl:
                "ctrl"
            case .shift:
                "shift"
            }
        }

        public var pressed: Bool {
            switch self {
            case .rcmd:
                KM.rcmd
            case .ralt:
                KM.ralt
            case .lcmd:
                KM.lcmd
            case .lalt:
                KM.lalt
            case .lctrl:
                KM.lctrl
            case .lshift:
                KM.lshift
            case .rshift:
                KM.rshift
            case .rctrl:
                KM.rctrl
            case .cmd:
                KM.rcmd || KM.lcmd
            case .alt:
                KM.ralt || KM.lalt
            case .ctrl:
                KM.rctrl || KM.lctrl
            case .shift:
                KM.rshift || KM.lshift
            }
        }

        public static func < (lhs: TriggerKey, rhs: TriggerKey) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public extension [TriggerKey] {
        static func == (lhs: Self, rhs: Self) -> Bool {
            Set(lhs) == Set(rhs)
        }

        var withoutShift: [TriggerKey] { filter { $0 != .lshift && $0 != .rshift } }
        var modifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.modifier))
        }

        var sideIndependentModifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.sideIndependentModifier))
        }

        var str: String { map(\.str).joined() }
        var directionalStr: String { map(\.directionalStr).joined() }
        var readableStr: String { map(\.readableStr).joined(separator: " + ") }
        var shortReadableStr: String { map(\.shortReadableStr).joined(separator: "+") }

        var allPressed: Bool { allSatisfy(\.pressed) }
        var allPressedExclusive: Bool { count == KM.flags.count && allPressed }

        func toggling(key: TriggerKey, on: Bool? = nil) -> [TriggerKey] {
            if on ?? !contains(key) {
                var keys = self
                if !contains(key) {
                    keys = keys + [key]
                }
                switch key {
                case .rcmd:
                    return keys.toggling(key: TriggerKey.lcmd, on: false)
                case .ralt:
                    return keys.toggling(key: TriggerKey.lalt, on: false)
                case .lcmd:
                    return keys.toggling(key: TriggerKey.rcmd, on: false)
                case .lalt:
                    return keys.toggling(key: TriggerKey.ralt, on: false)
                case .rshift:
                    return keys.toggling(key: TriggerKey.lshift, on: false)
                case .lshift:
                    return keys.toggling(key: TriggerKey.rshift, on: false)
                case .rctrl:
                    return keys.toggling(key: TriggerKey.lctrl, on: false)
                case .lctrl:
                    return keys.toggling(key: TriggerKey.rctrl, on: false)
                case .cmd:
                    return keys.toggling(key: TriggerKey.lcmd, on: false).toggling(key: TriggerKey.rcmd, on: false)
                case .alt:
                    return keys.toggling(key: TriggerKey.lalt, on: false).toggling(key: TriggerKey.ralt, on: false)
                case .ctrl:
                    return keys.toggling(key: TriggerKey.lctrl, on: false).toggling(key: TriggerKey.rctrl, on: false)
                case .shift:
                    return keys.toggling(key: TriggerKey.lshift, on: false).toggling(key: TriggerKey.rshift, on: false)
                }
            } else {
                let newTriggers = filter { $0 != key }
                return newTriggers.withoutShift.isEmpty ? [] : newTriggers
            }
        }
    }

    extension NSEvent.ModifierFlags {
        var triggerKeys: [TriggerKey] {
            var flags = [TriggerKey]()
            if contains(.leftShift) || (contains(.shift) && !contains(.rightShift)) { flags.append(.lshift) }
            if contains(.leftControl) || (contains(.control) && !contains(.rightControl)) { flags.append(.lctrl) }
            if contains(.leftOption) || (contains(.option) && !contains(.rightOption)) { flags.append(.lalt) }
            if contains(.leftCommand) || (contains(.command) && !contains(.rightCommand)) { flags.append(.lcmd) }
            if contains(.rightCommand) { flags.append(.rcmd) }
            if contains(.rightOption) { flags.append(.ralt) }
            if contains(.rightControl) { flags.append(.rctrl) }
            if contains(.rightShift) { flags.append(.rshift) }

            return flags
        }
    }

    public struct DirectionalModifierView: View {
        public init(triggerKeys: Binding<[TriggerKey]>, spacing: CGFloat = 3, noFG: Bool = false) {
            _triggerKeys = triggerKeys
            self.spacing = spacing
            self.noFG = noFG
        }

        @Environment(\.isEnabled) public var isEnabled

        public var body: some View {
            let rcmdTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.rcmd) || triggerKeys.contains(.cmd) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.rcmd, on: $0)
                }
            )
            let raltTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.ralt) || triggerKeys.contains(.alt) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.ralt, on: $0)
                }
            )

            let lcmdTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.lcmd) || triggerKeys.contains(.cmd) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.lcmd, on: $0)
                }
            )
            let laltTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.lalt) || triggerKeys.contains(.alt) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.lalt, on: $0)
                }
            )
            let lctrlTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.lctrl) || triggerKeys.contains(.ctrl) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.lctrl, on: $0)
                }
            )

            let lshiftTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.lshift) || triggerKeys.contains(.shift) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.lshift, on: $0)
                }
            )
            let rshiftTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.rshift) || triggerKeys.contains(.shift) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.rshift, on: $0)
                }
            )
            let rctrlTrigger = Binding<Bool>(
                get: { triggerKeys.contains(.rctrl) || triggerKeys.contains(.ctrl) },
                set: {
                    triggerKeys = triggerKeys.toggling(key: TriggerKey.rctrl, on: $0)
                }
            )

            HStack(spacing: spacing) {
                Button("⇧") {
                    triggerKeys = triggerKeys.toggling(key: .lshift)
                }.buttonStyle(ToggleButton(isOn: lshiftTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.shift) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Left Shift")
                Button("⌃") {
                    triggerKeys = triggerKeys.toggling(key: .lctrl)
                }.buttonStyle(ToggleButton(isOn: lctrlTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.ctrl) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Left Control")
                Button("⌥") {
                    triggerKeys = triggerKeys.toggling(key: .lalt)
                }.buttonStyle(ToggleButton(isOn: laltTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.alt) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Left Option")
                Button("⌘") {
                    triggerKeys = triggerKeys.toggling(key: .lcmd)
                }.buttonStyle(ToggleButton(isOn: lcmdTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.cmd) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Left Command")
                Button("    ⎵    ") {}
                    .buttonStyle(ToggleButton(isOn: .constant(false), noFG: noFG))
                    .opacity(0.9)
                    .disabled(true)
                    .accessibilityHidden(true)
                Button("⌘") {
                    triggerKeys = triggerKeys.toggling(key: .rcmd)
                }.buttonStyle(ToggleButton(isOn: rcmdTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.cmd) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Right Command")
                Button("⌥") {
                    triggerKeys = triggerKeys.toggling(key: .ralt)
                }.buttonStyle(ToggleButton(isOn: raltTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.alt) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Right Option")
                Button("⌃") {
                    triggerKeys = triggerKeys.toggling(key: .rctrl)
                }.buttonStyle(ToggleButton(isOn: rctrlTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.ctrl) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Right Control")
                Button("⇧") {
                    triggerKeys = triggerKeys.toggling(key: .rshift)
                }.buttonStyle(ToggleButton(isOn: rshiftTrigger, noFG: noFG))
                    .overlay(Colors.red.opacity(triggerKeys.contains(.shift) ? 0.1 : 0.0).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .accessibilityLabel("Toggle Right Shift")
            }.disabled(!isEnabled)
        }

        @Binding var triggerKeys: [TriggerKey]
        var spacing: CGFloat = 3
        var noFG = false
    }

    import Carbon

    public extension SauceKey {
        var character: String {
            switch QWERTYKeyCode.i {
            case kVK_Return: "⏎"
            case kVK_Space: "⎵"
            default: Sauce.shared.character(for: QWERTYKeyCode.i, cocoaModifiers: [])?.uppercased() ?? rawValue.uppercased()
            }
        }

        var QWERTYCharacter: String {
            switch QWERTYKeyCode.i {
            case kVK_ANSI_0: "0"
            case kVK_ANSI_1: "1"
            case kVK_ANSI_2: "2"
            case kVK_ANSI_3: "3"
            case kVK_ANSI_4: "4"
            case kVK_ANSI_5: "5"
            case kVK_ANSI_6: "6"
            case kVK_ANSI_7: "7"
            case kVK_ANSI_8: "8"
            case kVK_ANSI_9: "9"
            case kVK_ISO_Section: "§"
            case kVK_ANSI_Equal: "="
            case kVK_ANSI_Minus: "-"
            case kVK_ANSI_RightBracket: "]"
            case kVK_ANSI_LeftBracket: "["
            case kVK_ANSI_Quote: "'"
            case kVK_ANSI_Semicolon: ";"
            case kVK_ANSI_Backslash: "\\"
            case kVK_ANSI_Comma: ","
            case kVK_ANSI_Slash: "/"
            case kVK_ANSI_Period: "."
            case kVK_ANSI_Grave: "`"
            case kVK_Return: "⏎"
            case kVK_Space: "⎵"
            default: rawValue.uppercased()
            }
        }
    }

#endif
