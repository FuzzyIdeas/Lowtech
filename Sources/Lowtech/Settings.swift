import Cocoa
import Combine
import Defaults
import Foundation
import Magnet

public extension Defaults.Keys {
    static let popoverClosed = Key<Bool>("popoverClosed", default: true)
    static let hideMenubarIcon = Key<Bool>("hideMenubarIcon", default: false)
    static let launchCount = Key<Int>("launchCount", default: 0)
    static let autoRestartOnCrash = Key<Bool>("autoRestartOnCrash", default: true)
    static let autoRestartOnHang = Key<Bool>("autoRestartOnHang", default: true)
}

public func first<T>(this: T, other _: T) -> T {
    this
}

public func last<T>(this _: T, other: T) -> T {
    other
}

public func pub<T: Equatable>(_ key: Defaults.Key<T>) -> Publishers.Filter<Publishers.RemoveDuplicates<Publishers.Drop<AnyPublisher<Defaults.KeyChange<T>, Never>>>> {
    Defaults.publisher(key).dropFirst().removeDuplicates().filter { $0.oldValue != $0.newValue }
}
