//
//  Keys.swift
//
//
//  Created by Alin Panaitiu on 21.01.2022.
//

import Atomics
import Defaults
import Foundation

var _rcmd = ManagedAtomic<Bool>(false)
public var rcmd: Bool {
    get { _rcmd.load(ordering: .relaxed) }
    set { _rcmd.store(newValue, ordering: .sequentiallyConsistent) }
}

var _ralt = ManagedAtomic<Bool>(false)
public var ralt: Bool {
    get { _ralt.load(ordering: .relaxed) }
    set { _ralt.store(newValue, ordering: .sequentiallyConsistent) }
}

var _rshift = ManagedAtomic<Bool>(false)
public var rshift: Bool {
    get { _rshift.load(ordering: .relaxed) }
    set { _rshift.store(newValue, ordering: .sequentiallyConsistent) }
}

var _rctrl = ManagedAtomic<Bool>(false)
public var rctrl: Bool {
    get { _rctrl.load(ordering: .relaxed) }
    set { _rctrl.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lcmd = ManagedAtomic<Bool>(false)
public var lcmd: Bool {
    get { _lcmd.load(ordering: .relaxed) }
    set { _lcmd.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lalt = ManagedAtomic<Bool>(false)
public var lalt: Bool {
    get { _lalt.load(ordering: .relaxed) }
    set { _lalt.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lctrl = ManagedAtomic<Bool>(false)
public var lctrl: Bool {
    get { _lctrl.load(ordering: .relaxed) }
    set { _lctrl.store(newValue, ordering: .sequentiallyConsistent) }
}

var _lshift = ManagedAtomic<Bool>(false)
public var lshift: Bool {
    get { _lshift.load(ordering: .relaxed) }
    set { _lshift.store(newValue, ordering: .sequentiallyConsistent) }
}

#if os(macOS)
    import Cocoa

    public enum TriggerKey: Int, Codable, Defaults.Serializable, Comparable {
        case lshift
        case lctrl
        case lalt
        case lcmd
        case rcmd
        case ralt
        case rctrl
        case rshift

        // MARK: Public

        public var modifier: NSEvent.ModifierFlags {
            switch self {
            case .rcmd:
                return .rightCommand
            case .ralt:
                return .rightOption
            case .lcmd:
                return .leftCommand
            case .lalt:
                return .leftOption
            case .lctrl:
                return .leftControl
            case .lshift:
                return .leftShift
            case .rshift:
                return .rightShift
            case .rctrl:
                return .rightControl
            }
        }

        public var sideIndependentModifier: NSEvent.ModifierFlags {
            switch self {
            case .rcmd:
                return .command
            case .ralt:
                return .option
            case .lcmd:
                return .command
            case .lalt:
                return .option
            case .lctrl:
                return .control
            case .lshift:
                return .shift
            case .rshift:
                return .shift
            case .rctrl:
                return .control
            }
        }

        public var directionalStr: String {
            switch self {
            case .rcmd:
                return "⌘⃗"
            case .ralt:
                return "⌥⃗"
            case .lcmd:
                return "⌘⃖"
            case .lalt:
                return "⌥⃖"
            case .lctrl:
                return "^⃖"
            case .lshift:
                return "⇧⃖"
            case .rshift:
                return "⇧⃗"
            case .rctrl:
                return "^⃗"
            }
        }

        public var str: String {
            switch self {
            case .rcmd:
                return "⌘"
            case .ralt:
                return "⌥"
            case .lcmd:
                return "⌘"
            case .lalt:
                return "⌥"
            case .lctrl:
                return "^"
            case .lshift:
                return "⇧"
            case .rshift:
                return "⇧"
            case .rctrl:
                return "^"
            }
        }

        public static func < (lhs: TriggerKey, rhs: TriggerKey) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        // MARK: Internal

        var readableStr: String {
            switch self {
            case .rcmd:
                return "Right Command"
            case .ralt:
                return "Right Option"
            case .lcmd:
                return "Left Command"
            case .lalt:
                return "Left Option"
            case .lctrl:
                return "Left Control"
            case .lshift:
                return "Left Shift"
            case .rshift:
                return "Right Shift"
            case .rctrl:
                return "Right Control"
            }
        }

        var pressed: Bool {
            switch self {
            case .rcmd:
                return _rcmd.load(ordering: .relaxed)
            case .ralt:
                return _ralt.load(ordering: .relaxed)
            case .lcmd:
                return _lcmd.load(ordering: .relaxed)
            case .lalt:
                return _lalt.load(ordering: .relaxed)
            case .lctrl:
                return _lctrl.load(ordering: .relaxed)
            case .lshift:
                return _lshift.load(ordering: .relaxed)
            case .rshift:
                return _rshift.load(ordering: .relaxed)
            case .rctrl:
                return _rctrl.load(ordering: .relaxed)
            }
        }
    }

    public extension Array where Element == TriggerKey {
        var withoutShift: [TriggerKey] { filter { $0 != .lshift && $0 != .rshift } }
        var modifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.modifier))
        }

        var sideIndependentModifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.sideIndependentModifier))
        }

        var str: String { map(\.str).joined() }
        var directionalStr: String { map(\.directionalStr).joined() }
        var allPressed: Bool { allSatisfy(\.pressed) }

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
                }
            } else {
                let newTriggers = filter { $0 != key }
                return newTriggers.withoutShift.isEmpty ? [] : newTriggers
            }
        }
    }
#endif
