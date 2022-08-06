import Cocoa
import Combine
import Defaults
import Foundation
import Magnet

public extension Defaults.Keys {
    static let popoverClosed = Key<Bool>("popoverClosed", default: true)
    static let hideMenubarIcon = Key<Bool>("hideMenubarIcon", default: false)
    static let launchCount = Key<Int>("launchCount", default: 0)
}

public func first<T>(this: T, other _: T) -> T {
    this
}

public func last<T>(this _: T, other: T) -> T {
    other
}
