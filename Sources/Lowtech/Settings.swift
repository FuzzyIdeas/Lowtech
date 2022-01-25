import Cocoa
import Combine
import Defaults
import Foundation
import Magnet

#if os(macOS)
    import Cocoa

    enum TriggerKey: Int, Codable, Defaults.Serializable, Comparable {
        case lshift
        case lctrl
        case lalt
        case lcmd
        case rcmd
        case ralt
        case rctrl
        case rshift

        // MARK: Internal

        var modifier: NSEvent.ModifierFlags {
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

        var sideIndependentModifier: NSEvent.ModifierFlags {
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

        var directionalStr: String {
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

        var str: String {
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

        static func < (lhs: TriggerKey, rhs: TriggerKey) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    extension Array where Element == TriggerKey {
        var withoutShift: [TriggerKey] { filter { $0 != .lshift && $0 != .rshift } }
        var modifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.modifier))
        }

        var sideIndependentModifiers: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(map(\.sideIndependentModifier))
        }

        var str: String { map(\.str).joined() }

        var allPressed: Bool {
            var result = true
            forEach { key in
                switch key {
                case .rcmd:
                    result = result && rcmd
                case .ralt:
                    result = result && ralt
                case .lcmd:
                    result = result && lcmd
                case .lalt:
                    result = result && lalt
                case .lctrl:
                    result = result && lctrl
                case .lshift:
                    result = result && lshift
                case .rshift:
                    result = result && rshift
                case .rctrl:
                    result = result && rctrl
                }
            }
            return result
        }

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

extension Defaults.Keys {
    static let notificationsPermissionsGranted = Key<Bool>("notificationsPermissionsGranted", default: false)
    static let popoverClosed = Key<Bool>("popoverClosed", default: true)
    static let hideMenubarIcon = Key<Bool>("hideMenubarIcon", default: false)
    static let launchCount = Key<Int>("launchCount", default: 0)
}

func first<T>(this: T, other _: T) -> T {
    this
}
