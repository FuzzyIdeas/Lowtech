import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - AnimationSpeed

public enum AnimationSpeed: String, Codable, Defaults.Serializable {
    case fluid
    case snappy
    case instant

    // MARK: Public

    public var animation: Animation {
        switch self {
        case .fluid:
            return .jumpySpring
        case .snappy:
            return .quickSpring
        case .instant:
            return .fastSpring
        }
    }

    public var multiplier: Double {
        switch self {
        case .fluid:
            return 0.5
        case .snappy:
            return 1.25
        case .instant:
            return 1.75
        }
    }
}

public extension Defaults.Keys {
    static let allowAnimationsInLPM = Key<Bool>("allowAnimationsInLPM", default: false)
    static let animationSpeed = Key<AnimationSpeed>("animationSpeed", default: .snappy)
    static let allowAnimations = Key<Bool>("allowAnimations", default: true)
}

// MARK: - AnimationManager

public class AnimationManager: ObservableObject, ObservableSettings {
    // MARK: Lifecycle

    init() {
        initObservers()
    }

    // MARK: Public

    @MainActor public static let shared = AnimationManager()

    public static var isLowPowerModeEnabled: Bool {
        if #available(macOS 12.0, *) {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            return false
        }
    }

    public var observers: Set<AnyCancellable> = []
    public var apply = true

    @Setting(.animationSpeed) public var animationSpeed
    @Published public var animation = Defaults[.allowAnimations] && !shouldReduceMotion() ? Defaults[.animationSpeed].animation : .linear(duration: 0)

    @Published public var allowAnimationsInLPM = Defaults[.allowAnimationsInLPM] {
        didSet {
            reduceMotion = Self.shouldReduceMotion()
        }
    }

    @Published public var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || isLowPowerModeEnabled {
        didSet {
            animation = Defaults[.allowAnimations] && !reduceMotion ? Defaults[.animationSpeed].animation : .linear(duration: 0)
        }
    }

    @Published public var lowPowerMode = isLowPowerModeEnabled {
        didSet {
            reduceMotion = Self.shouldReduceMotion()
        }
    }

    public static func shouldReduceMotion() -> Bool {
        if !Defaults[.allowAnimationsInLPM], isLowPowerModeEnabled {
            return true
        }
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    public func initObservers() {
        bind(
            .animationSpeed,
            property: \.animation,
            transformer: .init(to: { Defaults[.allowAnimations] && !self.reduceMotion ? $0.animation : .linear(duration: 0) })
        )
        bind(
            .allowAnimations,
            property: \.animation,
            transformer: .init(to: { $0 && !self.reduceMotion ? Defaults[.animationSpeed].animation : .linear(duration: 0) })
        )
        bind(.allowAnimationsInLPM, property: \.allowAnimationsInLPM)

        NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { _ in self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            .store(in: &observers)

        if #available(macOS 12.0, *) {
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { _ in self.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled }
                .store(in: &observers)
        }
    }
}
