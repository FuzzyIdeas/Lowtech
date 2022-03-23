import Combine
import Foundation
import SwiftUI

public extension Substring {
    var s: String { String(self) }
}

public extension NumberFormatter {
    static let shared = NumberFormatter()
    static var formatters: [Formatting: NumberFormatter] = [:]

    static func formatter(decimals: Int = 0, padding: Int = 0) -> NumberFormatter {
        let f = NumberFormatter()
        if decimals > 0 {
            f.alwaysShowsDecimalSeparator = true
            f.maximumFractionDigits = decimals
            f.minimumFractionDigits = decimals
        }
        if padding > 0 {
            f.minimumIntegerDigits = padding
        }
        return f
    }

    static func shared(decimals: Int = 0, padding: Int = 0) -> NumberFormatter {
        guard let f = formatters[Formatting(decimals: decimals, padding: padding)] else {
            let newF = formatter(decimals: decimals, padding: padding)
            formatters[Formatting(decimals: decimals, padding: padding)] = newF
            return newF
        }
        return f
    }
}

#if os(macOS)
    import Cocoa

    public extension NSPopUpButton {
        /// Publishes index of selected Item
        var selectionPublisher: AnyPublisher<String?, Never> {
            NotificationCenter.default
                .publisher(for: NSMenu.didSendActionNotification, object: menu)
                .map { _ in self.selectedItem?.title }
                .eraseToAnyPublisher()
        }
    }

    public extension NSView {
        func trackHover(owner: Any? = nil, rect: NSRect? = nil, cursor: Bool = false) {
            for area in trackingAreas {
                removeTrackingArea(area)
            }
            let area = NSTrackingArea(
                rect: rect ?? bounds,
                options: cursor ? [.mouseEnteredAndExited, .cursorUpdate, .activeInActiveApp] :
                    [.mouseEnteredAndExited, .activeInActiveApp],
                owner: owner ?? self,
                userInfo: nil
            )
            addTrackingArea(area)
        }

        @inline(__always) func transition(
            _ duration: TimeInterval,
            type: CATransitionType = .fade,
            subtype: CATransitionSubtype = .fromTop,
            start: Float = 0.0,
            end: Float = 1.0,
            easing: CAMediaTimingFunction = .easeOutQuart,
            key: String = kCATransition
        ) {
            layer?.add(
                createTransition(duration: duration, type: type, subtype: subtype, start: start, end: end, easing: easing),
                forKey: key
            )
        }

        func center(within rect: NSRect, horizontally: Bool = true, vertically: Bool = true) {
            setFrameOrigin(CGPoint(
                x: horizontally ? rect.midX - frame.width / 2 : frame.origin.x,
                y: vertically ? rect.midY - frame.height / 2 : frame.origin.y
            ))
        }

        func center(within view: NSView, horizontally: Bool = true, vertically: Bool = true) {
            center(within: view.visibleRect, horizontally: horizontally, vertically: vertically)
        }

        @objc dynamic var bg: NSColor? {
            get {
                guard let layer = layer, let backgroundColor = layer.backgroundColor else { return nil }
                return NSColor(cgColor: backgroundColor)
            }
            set {
                mainAsync { [self] in
                    wantsLayer = true
                    layer?.backgroundColor = newValue?.cgColor
                }
            }
        }

        @objc dynamic var radius: NSNumber? {
            get {
                guard let layer = layer else { return nil }
                return NSNumber(value: Float(layer.cornerRadius))
            }
            set {
                wantsLayer = true
                layer?.cornerRadius = CGFloat(newValue?.floatValue ?? 0.0)
            }
        }
    }

    extension NSSize: Comparable {
        var area: CGFloat { width * height }
        public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
            lhs.area < rhs.area
        }
    }

    public extension NSAppearance {
        var isDark: Bool { name == .vibrantDark || name == .darkAqua }
    }

    public extension NSWindow {
        func shake(with intensity: CGFloat = 0.01, duration: Double = 0.3) {
            let numberOfShakes = 3
            let frame: CGRect = frame
            let shakeAnimation = CAKeyframeAnimation()

            let shakePath = CGMutablePath()
            shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))

            for _ in 0 ... numberOfShakes - 1 {
                shakePath.addLine(to: CGPoint(x: NSMinX(frame) - frame.size.width * intensity, y: NSMinY(frame)))
                shakePath.addLine(to: CGPoint(x: NSMinX(frame) + frame.size.width * intensity, y: NSMinY(frame)))
            }

            shakePath.closeSubpath()
            shakeAnimation.path = shakePath
            shakeAnimation.duration = duration

            animations = [NSAnimatablePropertyKey("frameOrigin"): shakeAnimation]
            animator().setFrameOrigin(self.frame.origin)
        }
    }

    public extension NSScreen {
        static func isOnline(_ id: CGDirectDisplayID) -> Bool {
            onlineDisplayIDs.contains(id)
        }

        static func isActive(_ id: CGDirectDisplayID) -> Bool {
            activeDisplayIDs.contains(id)
        }

        static var onlineDisplayIDs: [CGDirectDisplayID] {
            let maxDisplays: UInt32 = 16
            var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: maxDisplays.i)
            var displayCount: UInt32 = 0

            let err = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
            if err != .success {
                print("Error on getting online displays: \(err)")
            }

            return onlineDisplays.prefix(displayCount.i).arr
        }

        static var activeDisplayIDs: [CGDirectDisplayID] {
            let maxDisplays: UInt32 = 16
            var activeDisplays = [CGDirectDisplayID](repeating: 0, count: maxDisplays.i)
            var displayCount: UInt32 = 0

            let err = CGGetActiveDisplayList(maxDisplays, &activeDisplays, &displayCount)
            if err != .success {
                print("Error on getting active displays: \(err)")
            }

            return activeDisplays.prefix(displayCount.i).arr
        }

        static var onlyExternalScreen: NSScreen? {
            let screens = externalScreens
            guard screens.count == 1, let screen = screens.first else {
                return nil
            }

            return screen
        }

        static var externalScreens: [NSScreen] {
            screens.filter { !$0.isBuiltin }
        }

        static var withMouse: NSScreen? {
            screens.first { $0.hasMouse }
        }

        static var externalWithMouse: NSScreen? {
            screens.first { !$0.isBuiltin && $0.hasMouse }
        }

        var hasMouse: Bool {
            let mouseLocation = NSEvent.mouseLocation
            if NSMouseInRect(mouseLocation, frame, false) {
                return true
            }

            guard let event = CGEvent(source: nil) else {
                return false
            }

            let maxDisplays: UInt32 = 1
            var displaysWithCursor = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
            var displayCount: UInt32 = 0

            let err = CGGetDisplaysWithPoint(event.location, maxDisplays, &displaysWithCursor, &displayCount)
            if err != .success {
                print("Error on getting displays with mouse location: \(err)")
            }
            guard let id = displaysWithCursor.first else {
                return false
            }
            return id == displayID
        }

        static var builtinDisplayID: CGDirectDisplayID? {
            onlineDisplayIDs.first(where: { CGDisplayIsBuiltin($0) > 0 })
        }

        var displayID: CGDirectDisplayID? {
            guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return nil }
            return CGDirectDisplayID(id.uint32Value)
        }

        static var builtin: NSScreen? {
            screens.first(where: \.isBuiltin)
        }

        var isBuiltin: Bool {
            displayID != nil && CGDisplayIsBuiltin(displayID!) > 0
        }

        var isScreen: Bool {
            guard let isScreenStr = deviceDescription[NSDeviceDescriptionKey.isScreen] as? String else {
                return false
            }
            return isScreenStr == "YES"
        }

        static func forDisplayID(_ id: CGDirectDisplayID) -> NSScreen? {
            NSScreen.screens.first { $0.hasDisplayID(id) }
        }

        func hasDisplayID(_ id: CGDirectDisplayID) -> Bool {
            guard let screenNumber = displayID else { return false }
            return id == screenNumber
        }
    }

#endif

public extension Float {
    @inline(__always) func rounded(to scale: Int) -> Double {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale.i16,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )

        let roundedValue = NSDecimalNumber(value: self).rounding(accordingToBehavior: behavior)

        return roundedValue.doubleValue
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var i8: Int8 {
        Int8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var i16: Int16 {
        Int16(self)
    }

    @inline(__always) var i32: Int32 {
        Int32(self)
    }

    @inline(__always) var intround: Int {
        rounded().i
    }

    func str(decimals: UInt8, padding: UInt8 = 0) -> String {
        NumberFormatter.shared(decimals: decimals.i, padding: padding.i).string(from: ns) ?? String(format: "%.\(decimals)f", self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((self / value) * 100.0).str(decimals: decimals))%"
    }
}

public extension Double {
    @inline(__always) func rounded(to scale: Int) -> Double {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale.i16,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )

        let roundedValue = NSDecimalNumber(value: self).rounding(accordingToBehavior: behavior)

        return roundedValue.doubleValue
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) var f: Float {
        Float(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var i8: Int8 {
        Int8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) var i16: Int16 {
        Int16(self)
    }

    @inline(__always) var i32: Int32 {
        Int32(self)
    }

    @inline(__always) var intround: Int {
        rounded().i
    }

    func str(decimals: UInt8, padding: UInt8 = 0) -> String {
        NumberFormatter.shared(decimals: decimals.i, padding: padding.i).string(from: ns) ?? String(format: "%.\(decimals)f", self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((self / value) * 100.0).str(decimals: decimals))%"
    }
}

public extension UInt8 {
    var hex: String {
        String(format: "%02x", self)
    }

    var percentStr: String {
        "\((self / UInt8.max) * 100)%"
    }

    func str() -> String {
        if (0x20 ... 0x7E).contains(self),
           let value = NSString(bytes: [self], length: 1, encoding: String.Encoding.nonLossyASCII.rawValue) as String?
        {
            return value
        } else {
            return String(format: "%02x", self)
        }
    }
}

public extension BinaryInteger {
    @inline(__always) var ns: NSNumber {
        NSNumber(value: d)
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) var f: Float {
        Float(self)
    }

    @inline(__always) var u: UInt {
        UInt(self)
    }

    @inline(__always) var u8: UInt8 {
        UInt8(cap(self, minVal: 0, maxVal: 255))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) var u64: UInt64 {
        UInt64(self)
    }

    @inline(__always) var i: Int {
        Int(self)
    }

    @inline(__always) var i8: Int8 {
        Int8(self)
    }

    @inline(__always) var i16: Int16 {
        Int16(self)
    }

    @inline(__always) var i32: Int32 {
        Int32(self)
    }

    @inline(__always) var i64: Int64 {
        Int64(self)
    }

    @inline(__always) var s: String {
        String(self)
    }
}

public extension ArraySlice {
    var arr: [Element] {
        Array(self)
    }
}

public extension Set {
    var arr: [Element] {
        Array(self)
    }
}

public extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public extension CAMediaTimingFunction {
    // default
    static let `default` = CAMediaTimingFunction(name: .default)
    static let linear = CAMediaTimingFunction(name: .linear)
    static let easeIn = CAMediaTimingFunction(name: .easeIn)
    static let easeOut = CAMediaTimingFunction(name: .easeOut)
    static let easeInEaseOut = CAMediaTimingFunction(name: .easeInEaseOut)

    // custom
    static let easeInSine = CAMediaTimingFunction(controlPoints: 0.47, 0, 0.745, 0.715)
    static let easeOutSine = CAMediaTimingFunction(controlPoints: 0.39, 0.575, 0.565, 1)
    static let easeInOutSine = CAMediaTimingFunction(controlPoints: 0.445, 0.05, 0.55, 0.95)
    static let easeInQuad = CAMediaTimingFunction(controlPoints: 0.55, 0.085, 0.68, 0.53)
    static let easeOutQuad = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
    static let easeInOutQuad = CAMediaTimingFunction(controlPoints: 0.455, 0.03, 0.515, 0.955)
    static let easeInCubic = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
    static let easeOutCubic = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
    static let easeInOutCubic = CAMediaTimingFunction(controlPoints: 0.645, 0.045, 0.355, 1)
    static let easeInQuart = CAMediaTimingFunction(controlPoints: 0.895, 0.03, 0.685, 0.22)
    static let easeOutQuart = CAMediaTimingFunction(controlPoints: 0.165, 0.84, 0.44, 1)
    static let easeInOutQuart = CAMediaTimingFunction(controlPoints: 0.77, 0, 0.175, 1)
    static let easeInQuint = CAMediaTimingFunction(controlPoints: 0.755, 0.05, 0.855, 0.06)
    static let easeOutQuint = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    static let easeInOutQuint = CAMediaTimingFunction(controlPoints: 0.86, 0, 0.07, 1)
    static let easeInExpo = CAMediaTimingFunction(controlPoints: 0.95, 0.05, 0.795, 0.035)
    static let easeOutExpo = CAMediaTimingFunction(controlPoints: 0.19, 1, 0.22, 1)
    static let easeInOutExpo = CAMediaTimingFunction(controlPoints: 1, 0, 0, 1)
    static let easeInCirc = CAMediaTimingFunction(controlPoints: 0.6, 0.04, 0.98, 0.335)
    static let easeOutCirc = CAMediaTimingFunction(controlPoints: 0.075, 0.82, 0.165, 1)
    static let easeInOutCirc = CAMediaTimingFunction(controlPoints: 0.785, 0.135, 0.15, 0.86)
    static let easeInBack = CAMediaTimingFunction(controlPoints: 0.6, -0.28, 0.735, 0.045)
    static let easeOutBack = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
    static let easeInOutBack = CAMediaTimingFunction(controlPoints: 0.68, -0.55, 0.265, 1.55)
}

public extension CGFloat {
    @inline(__always) var i32: Int32 {
        Int32(self)
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: Float(self))
    }
}

public extension Data {
    var s: String? { String(data: self, encoding: .utf8) }

    func str(hex: Bool = false, base64: Bool = false, urlSafe: Bool = false, separator: String = " ") -> String {
        if base64 {
            let b64str = base64EncodedString(options: [])
            return urlSafe ? b64str.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? b64str : b64str
        }

        if hex {
            let hexstr = map(\.hex).joined(separator: separator)
            return urlSafe ? hexstr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? hexstr : hexstr
        }

        if let string = String(data: self, encoding: .utf8) {
            return urlSafe ? string.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? string : string
        }

        let rawstr = compactMap { String(Character(Unicode.Scalar($0))) }.joined(separator: separator)
        return urlSafe ? rawstr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? rawstr : rawstr
    }
}

public extension String {
    @inline(__always) var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /**
     Counts the occurrences of a given substring by calling Strings `range(of:options:range:locale:)` method multiple times.

     - Parameter substring : The string to search for, optional for convenience

     - Parameter allowOverlap : Bool flag indicating whether the matched substrings may overlap. Count of "🐼🐼" in "🐼🐼🐼🐼" is 2 if allowOverlap is **false**, and 3 if it is **true**

     - Parameter options : String compare-options to use while counting

     - Parameter range : An optional range to limit the search, default is **nil**, meaning search whole string

     - Parameter locale : Locale to use while counting

     - Returns : The number of occurrences of the substring in this String
     */
    func count(
        occurrencesOf substring: String?,
        allowOverlap: Bool = false,
        options: String.CompareOptions = [],
        range searchRange: Range<String.Index>? = nil,
        locale: Locale? = nil
    ) -> Int {
        guard let substring = substring, !substring.isEmpty else { return 0 }

        var count = 0

        let searchRange = searchRange ?? startIndex ..< endIndex

        var searchStartIndex = searchRange.lowerBound
        let searchEndIndex = searchRange.upperBound

        while let rangeFound = range(of: substring, options: options, range: searchStartIndex ..< searchEndIndex, locale: locale) {
            count += 1

            if allowOverlap {
                searchStartIndex = index(rangeFound.lowerBound, offsetBy: 1)
            } else {
                searchStartIndex = rangeFound.upperBound
            }
        }

        return count
    }
}

public extension CharacterSet {
    func characters() -> [Character] {
        // A Unicode scalar is any Unicode code point in the range U+0000 to U+D7FF inclusive or U+E000 to U+10FFFF inclusive.
        codePoints().compactMap { UnicodeScalar($0) }.map { Character($0) }
    }

    func codePoints() -> [Int] {
        var result: [Int] = []
        var plane = 0
        // following documentation at https://developer.apple.com/documentation/foundation/nscharacterset/1417719-bitmaprepresentation
        for (i, w) in bitmapRepresentation.enumerated() {
            let k = i % 0x2001
            if k == 0x2000 {
                // plane index byte
                plane = Int(w) << 13
                continue
            }
            let base = (plane + k) << 3
            for j in 0 ..< 8 where w & 1 << j != 0 {
                result.append(base + j)
            }
        }
        return result
    }
}

public extension Published.Publisher {
    var didSet: AnyPublisher<Value, Never> {
        receive(on: RunLoop.main).eraseToAnyPublisher()
    }
}

public extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

public extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element {
        reduce(.zero, +)
    }
}

public extension View {
    func size(size: Binding<CGSize>) -> some View {
        ChildSizeReader(size: size) {
            self
        }
    }
}

public extension Array where Element: Equatable & Hashable {
    var uniqued: Self { Set(self).arr }
    func replacing(at index: Index, with element: Element) -> Self {
        enumerated().map { $0.offset == index ? element : $0.element }
    }

    func replacing(_ element: Element, with newElement: Element) -> Self {
        map { $0 == element ? newElement : $0 }
    }

    func without(index: Index) -> Self {
        enumerated().filter { $0.offset != index }.map(\.element)
    }

    func without(indices: [Index]) -> Self {
        enumerated().filter { !indices.contains($0.offset) }.map(\.element)
    }

    func without(_ element: Element) -> Self {
        filter { $0 != element }
    }

    func without(_ elements: [Element]) -> Self {
        filter { !elements.contains($0) }
    }

    func after(_ element: Element) -> Element? {
        guard let idx = firstIndex(of: element) else { return nil }
        return self[safe: index(after: idx)]
    }
}

public extension StringProtocol {
    func distance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
    func distance<S: StringProtocol>(of string: S) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
}

public extension Collection {
    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }
}

public extension String.Index {
    func distance<S: StringProtocol>(in string: S) -> Int { string.distance(to: self) }
}

public extension NSParagraphStyle {
    static var centered: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
    }
}
