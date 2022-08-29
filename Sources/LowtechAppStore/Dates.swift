import Foundation
import SwiftDate

@inline(__always)
public func localTimeSince(_ date: Date) -> TimeInterval {
    DateInRegion().convertTo(region: .local) - date.convertTo(region: .local)
}

@inline(__always)
public func localTimeUntil(_ date: Date) -> TimeInterval {
    date.convertTo(region: .local) - DateInRegion().convertTo(region: .local)
}
