import Foundation
import SwiftDate

@inline(__always) @inlinable
public func localTimeSince(_ date: Date) -> TimeInterval {
    DateInRegion().convertTo(region: .local) - date.convertTo(region: .local)
}

@inline(__always) @inlinable
public func localTimeUntil(_ date: Date) -> TimeInterval {
    date.convertTo(region: .local) - DateInRegion().convertTo(region: .local)
}
