import Combine
import Foundation
import SwiftUI

public prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}

public prefix func ! <T>(keyPath: KeyPath<T, Bool>) -> (T) -> Bool {
    { !$0[keyPath: keyPath] }
}

prefix operator !?
public prefix func !? <T>(keyPath: KeyPath<T, (some Any)?>) -> (T) -> Bool {
    { $0[keyPath: keyPath] != nil }
}

public func == <T, V: Equatable>(lhs: KeyPath<T, V>, rhs: V) -> (T) -> Bool {
    { $0[keyPath: lhs] == rhs }
}

public func != <T, V: Equatable>(lhs: KeyPath<T, V>, rhs: V) -> (T) -> Bool {
    { $0[keyPath: lhs] != rhs }
}

infix operator ?!

public func ?! (_ str: String?, _ str2: String) -> String {
    guard let str, !str.isEmpty else {
        return str2
    }
    return str
}

public func ?! <T: Collection>(_ seq: T?, _ seq2: T) -> T {
    guard let seq, !seq.isEmpty else {
        return seq2
    }
    return seq
}

public func % (_ str: String, _ args: [CVarArg]) -> String {
    String(format: str, arguments: args.map { String(describing: $0) })
}

public func % (_ str: String, _ arg: CVarArg) -> String {
    String(format: str, arguments: [String(describing: arg)])
}

public extension Substring.SubSequence {
    var s: String { String(self) }
}

public extension String.SubSequence {
    @inline(__always) var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) var i32: Int32? {
        Int32(self)
    }

    @inline(__always) var d: Double? {
        Double(self)
    }
}

public extension Animation {
    #if os(iOS)
        static let fastTransition = Animation.easeOut(duration: 0.1)
    #else
        static let fastTransition = Animation.interactiveSpring(dampingFraction: 0.7)
    #endif
    static let fastSpring = Animation.interactiveSpring(dampingFraction: 0.7)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.65)
    static let jumpySpring = Animation.spring(response: 0.4, dampingFraction: 0.45)
    static let veryJumpySpring = Animation.spring(response: 0.4, dampingFraction: 0.25)
}

// MARK: - NumberFormatting

struct NumberFormatting: Hashable {
    let decimals: Int
    let padding: Int
    let format: String?
    let decimalSeparator: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(padding)
        hasher.combine(decimals)
        hasher.combine(format)
        hasher.combine(decimalSeparator)
    }
}

extension NumberFormatter {
    static let shared = NumberFormatter()
    static var formatters: [NumberFormatting: NumberFormatter] = [:]

    static func formatter(decimals: Int = 0, padding: Int = 0, format: String? = nil, decimalSeparator: String? = nil) -> NumberFormatter {
        let f = NumberFormatter()
        if decimals > 0 {
            f.alwaysShowsDecimalSeparator = true
            f.maximumFractionDigits = decimals
            f.minimumFractionDigits = decimals
            if let decimalSeparator {
                f.decimalSeparator = decimalSeparator
            }
        }
        if padding > 0 {
            f.minimumIntegerDigits = padding
        }

        if let format {
            f.positiveFormat = format
            f.negativeFormat = format
        }

        return f
    }

    static func shared(decimals: Int = 0, padding: Int = 0, format: String? = nil, decimalSeparator: String? = nil) -> NumberFormatter {
        guard let f = formatters[NumberFormatting(decimals: decimals, padding: padding, format: format, decimalSeparator: decimalSeparator)]
        else {
            let newF = formatter(decimals: decimals, padding: padding, format: format, decimalSeparator: decimalSeparator)
            formatters[NumberFormatting(decimals: decimals, padding: padding, format: format, decimalSeparator: decimalSeparator)] = newF
            return newF
        }
        return f
    }
}

public extension Bool {
    @inline(__always) var i: Int {
        self ? 1 : 0
    }

    #if os(macOS)
        @inline(__always) var state: NSControl.StateValue {
            self ? .on : .off
        }
    #endif
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
                guard let layer, let backgroundColor = layer.backgroundColor else { return nil }
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
                guard let layer else { return nil }
                return NSNumber(value: Float(layer.cornerRadius))
            }
            set {
                wantsLayer = true
                layer?.cornerRadius = CGFloat(newValue?.floatValue ?? 0.0)
                layer?.cornerCurve = .continuous
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

    func str(decimals: UInt8, padding: UInt8 = 0, separator: String? = nil) -> String {
        NumberFormatter.shared(decimals: decimals.i, padding: padding.i, decimalSeparator: separator)
            .string(from: ns) ?? String(format: "%.\(decimals)f", self)
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

    func str(decimals: UInt8, padding: UInt8 = 0, separator: String? = nil) -> String {
        NumberFormatter.shared(decimals: decimals.i, padding: padding.i, decimalSeparator: separator)
            .string(from: ns) ?? String(format: "%.\(decimals)f", self)
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

infix operator %%

public extension BinaryInteger {
    @inline(__always)
    static func %% (_ a: Self, _ n: Self) -> Self {
        precondition(n > 0, "modulus must be positive")
        let r = a % n
        return r >= 0 ? r : r + n
    }

    @inline(__always) var ns: NSNumber {
        NSNumber(value: d)
    }

    @inline(__always) var d: Double {
        Double(self)
    }

    @inline(__always) var cg: CGGammaValue {
        CGGammaValue(self)
    }

    @inline(__always) var f: Float {
        Float(self)
    }

    @inline(__always) var u: UInt {
        UInt(max(self, 0))
    }

    @inline(__always) var u8: UInt8 {
        UInt8(max(self, 0))
    }

    @inline(__always) var u16: UInt16 {
        UInt16(max(self, 0))
    }

    @inline(__always) var u32: UInt32 {
        UInt32(max(self, 0))
    }

    @inline(__always) var u64: UInt64 {
        UInt64(max(self, 0))
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
        Int32(cap(Int(self), minVal: Int(Int32.min), maxVal: Int(Int32.max)))
    }

    @inline(__always) var i64: Int64 {
        Int64(self)
    }

    @inline(__always) var s: String {
        String(self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((d / value.d) * 100.0).str(decimals: decimals))%"
    }
}

public extension String {
    func parseHex(strict: Bool = false) -> Int? {
        guard !strict || starts(with: "0x") || starts(with: "x") || hasSuffix("h") else { return nil }

        var sub = self

        if sub.starts(with: "0x") {
            sub = String(sub.suffix(from: sub.index(sub.startIndex, offsetBy: 2)))
        }

        if sub.starts(with: "x") {
            sub = String(sub.suffix(from: sub.index(after: sub.startIndex)))
        }

        if sub.hasSuffix("h") {
            sub = String(sub.prefix(sub.count - 1))
        }

        return Int(sub, radix: 16)
    }

    @inline(__always) var d: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.doubleValue
    }

    @inline(__always) var f: Float? {
        Float(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.floatValue
    }

    @inline(__always) var u: UInt? {
        UInt(self)
    }

    @inline(__always) var u8: UInt8? {
        UInt8(self)
    }

    @inline(__always) var u16: UInt16? {
        UInt16(self)
    }

    @inline(__always) var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) var u64: UInt64? {
        UInt64(self)
    }

    @inline(__always) var i: Int? {
        Int(self)
    }

    @inline(__always) var i8: Int8? {
        Int8(self)
    }

    @inline(__always) var i16: Int16? {
        Int16(self)
    }

    @inline(__always) var i32: Int32? {
        Int32(self)
    }

    @inline(__always) var i64: Int64? {
        Int64(self)
    }

    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }

    func titleCase() -> String {
        replacingOccurrences(
            of: "([A-Z])",
            with: " $1",
            options: .regularExpression,
            range: range(of: self)
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .capitalized
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

    func hasElements(from otherSet: Set<Element>) -> Bool {
        !intersection(otherSet).isEmpty
    }
}

public extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    var isNotEmpty: Bool { !isEmpty }
}

public extension SetAlgebra {
    var isNotEmpty: Bool { !isEmpty }
}

public extension Sequence {
    func dict<K: Hashable, V>(uniqueByLast: Bool = false, _ transformer: (Element) -> (K, V)?) -> [K: V] {
        Dictionary(compactMap(transformer), uniquingKeysWith: uniqueByLast ? last(this:other:) : first(this:other:))
    }

    func group<K: Hashable>(by key: KeyPath<Element, K?>, ignoring: Set<K>? = nil) -> [K: [Element]] {
        var grouped = [K: [Element]]()
        for v in self {
            guard let k = v[keyPath: key], !(ignoring?.contains(k) ?? false) else { continue }
            guard grouped[k] != nil else {
                grouped[k] = [v]
                continue
            }

            grouped[k]!.append(v)
        }

        return grouped
    }

    func group<K: Hashable>(by key: KeyPath<Element, K>, ignoring: Set<K>? = nil) -> [K: [Element]] {
        var grouped = [K: [Element]]()
        for v in self {
            let k = v[keyPath: key]
            guard !(ignoring?.contains(k) ?? false) else { continue }
            guard grouped[k] != nil else {
                grouped[k] = [v]
                continue
            }

            grouped[k]!.append(v)
        }

        return grouped
    }

    func first(_ count: Int, where condition: (Element) -> Bool) -> [Element] {
        var results = [Element]()
        results.reserveCapacity(count)

        for elem in self {
            if results.count == count { return results }
            if condition(elem) {
                results.append(elem)
            }
        }

        return results
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
        guard let substring, !substring.isEmpty else { return 0 }

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
    @ViewBuilder func `if`(_ condition: @autoclosure () -> Bool, transform: (Self) -> some View) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder func ifLet<T>(_ condition: @autoclosure () -> T?, transform: (Self, T) -> some View) -> some View {
        if let param = condition() {
            transform(self, param)
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

public extension Set where Element: Equatable & Hashable {
    func without(_ element: Element) -> Set<Element> {
        subtracting([element])
    }

    func without(_ elements: Set<Element>) -> Set<Element> {
        subtracting(elements)
    }

    func with(_ element: Element) -> Set<Element> {
        union([element])
    }
}

public extension Sequence where Element: Equatable & Hashable {
    func without(_ element: Element) -> [Element] {
        filter { $0 != element }
    }

    func without(_ elements: Set<Element>) -> [Element] {
        filter { !elements.contains($0) }
    }

    var uniqued: [Element] { Set(self).arr }

    func replacing(_ element: Element, with newElement: Element) -> [Element] {
        map { $0 == element ? newElement : $0 }
    }

    func without(_ elements: [Element]) -> [Element] {
        let elSet = Set(elements)
        return filter { !elSet.contains($0) }
    }
}

public extension Collection where Element: Equatable & Hashable, Index: BinaryInteger {
    func replacing(at index: Index, with element: Element) -> [Element] {
        enumerated().map { $0.offset == index ? element : $0.element }
    }

    func without(index: Index) -> [Element] {
        enumerated().filter { $0.offset != index }.map(\.element)
    }

    func without(indices: [Index]) -> [Element] {
        enumerated().filter { !indices.contains(Index($0.offset)) }.map(\.element)
    }

    func after(_ element: Element) -> Element? {
        guard let idx = firstIndex(of: element) else { return nil }
        return self[safe: index(after: idx)]
    }

    func after(_ element: Element?) -> Element? {
        guard let element, let idx = firstIndex(of: element) else { return nil }
        return self[safe: index(after: idx)]
    }
}

public extension StringProtocol {
    func distance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
    func distance(of string: some StringProtocol) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
}

// MARK: - BackportSortOrder

public enum BackportSortOrder {
    case forward
    case reverse
}

public extension Collection {
    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }

//    @available(macOS 12.0, *)
//    func sorted<Value: Comparable>(by keyPath: KeyPath<Element, Value>, order: SortOrder) -> [Element] {
//        return sorted(using: KeyPathComparator(keyPath, order: order))
//    }

    func sorted(by keyPath: KeyPath<Element, some Comparable>, order: BackportSortOrder = .forward) -> [Element] {
        sorted(by: { e1, e2 in
            switch order {
            case .forward:
                return e1[keyPath: keyPath] < e2[keyPath: keyPath]
            case .reverse:
                return e1[keyPath: keyPath] > e2[keyPath: keyPath]
            }
        })
    }

    func max(by keyPath: KeyPath<Element, some Comparable>) -> Element? {
        self.max(by: { e1, e2 in
            e1[keyPath: keyPath] < e2[keyPath: keyPath]
        })
    }

    func min(by keyPath: KeyPath<Element, some Comparable>) -> Element? {
        self.min(by: { e1, e2 in
            e1[keyPath: keyPath] < e2[keyPath: keyPath]
        })
    }
}

public extension String.Index {
    func distance(in string: some StringProtocol) -> Int { string.distance(to: self) }
}

public extension NSParagraphStyle {
    static var centered: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
    }
}

public extension Binding where Value == Bool {
    static let `false`: Binding<Value> = .constant(false)
    static let `true`: Binding<Value> = .constant(true)
}

public extension Binding {
    static func oneway(getter: @escaping () -> Value) -> Binding {
        Binding(get: getter, set: { _ in })
    }

    var optional: Binding<Value?> {
        .oneway { self.wrappedValue }
    }
}

public extension Sequence<UInt8> {
    func hexEncodedString(upperCased: Bool = false) -> String {
        let format = upperCased ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

public extension OptionSet {
    mutating func toggle(_ element: Element, minSet: Self? = nil, emptySet: Self? = nil) {
        if contains(element) {
            remove(element)
            if let minSet, isEmpty || (emptySet?.isSuperset(of: self) ?? false) {
                formUnion(minSet)
            }
        } else {
            insert(element)
        }
    }
}

public extension Bundle {
    var name: String? {
        infoDictionary?["CFBundleName"] as? String ?? executable?.basename(dropExtension: true)
    }

    var isMenuBarApp: Bool {
        (object(forInfoDictionaryKey: "LSUIElement") as? Bool) ?? false
    }
}

import MemoZ

public extension NSRunningApplication {
    var binaryIsValid: Bool {
        binaryValidCache.fetch(key: identifier, create: { _ in
            guard let bundleExe = bundle?.executable?.fileReferenceURL, let exePath = executableURL?.path,
                  let exe = p(exePath)?.fileReferenceURL else { return true }
            return bundleExe == exe
        })
    }

    var isRegular: Bool {
        activationPolicyCache.fetch(key: identifier, create: { _ in activationPolicy }) == .regular
    }

    var identifier: String {
        guard let bundleIdentifier else { return processIdentifier.s }
        return "\(bundleIdentifier):\(processIdentifier)"
    }

    static func runningApplications(withIdentifier identifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first(where: { $0.identifier == identifier })
    }

    var bundleName: String? {
        bundle?.name
    }

    var name: String? { localizedName ?? bundleName }

    var bundle: Bundle? {
        guard let bundleURL else {
            return nil
        }

        return bundleCache.fetch(key: bundleURL, create: { url in Bundle(url: url) })
    }

    func binaryMatchesLaunchDate(path: String) -> Bool {
        let binaryModifiedDate = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        guard let launchDate, let binaryModifiedDate else { return true }

        #if DEBUG
            print("Launch date: \(launchDate)")
            print("Binary modified date: \(binaryModifiedDate)")
        #endif

        return binaryModifiedDate <= launchDate || ignoredBinaryDates[path] == binaryModifiedDate
    }
}

var ignoredBinaryDates: [String: Date] = [:]
var activationPolicyCache = Cache<String, NSApplication.ActivationPolicy>()
let bundleCache = Cache<URL, Bundle?>()
let binaryValidCache = Cache<String, Bool>()

public extension URL {
    /// Get extended attribute.
    func extendedAttribute(forName name: String) throws -> Data {
        let data = try withUnsafeFileSystemRepresentation { fileSystemPath -> Data in

            // Determine attribute size:
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var data = Data(count: length)

            // Retrieve attribute:
            let result = data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
            return data
        }
        return data
    }

    /// Set extended attribute.
    func setExtendedAttribute(data: Data, forName name: String) throws {
        try withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }

    /// Remove extended attribute.
    func removeExtendedAttribute(forName name: String) throws {
        try withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = removexattr(fileSystemPath, name, 0)
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }

    /// Get list of all extended attributes.
    func listExtendedAttributes() throws -> [String] {
        let list = try withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
            let length = listxattr(fileSystemPath, nil, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var namebuf = [CChar](repeating: 0, count: length)

            // Retrieve attribute list:
            let result = listxattr(fileSystemPath, &namebuf, namebuf.count, 0)
            guard result >= 0 else { throw URL.posixError(errno) }

            // Extract attribute names:
            let list = namebuf.split(separator: 0).compactMap {
                $0.withUnsafeBufferPointer {
                    $0.withMemoryRebound(to: UInt8.self) {
                        String(bytes: $0, encoding: .utf8)
                    }
                }
            }
            return list
        }
        return list
    }

    /// Helper function to create an NSError from a Unix errno.
    private static func posixError(_ err: Int32) -> NSError {
        NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(err),
            userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))]
        )
    }
}

import Defaults

public extension Defaults.Serializable where Self: Codable {
    static var bridge: Defaults.TopLevelCodableBridge<Self> { Defaults.TopLevelCodableBridge() }
}

public extension Defaults.Serializable where Self: Codable & NSSecureCoding {
    static var bridge: Defaults.CodableNSSecureCodingBridge<Self> { Defaults.CodableNSSecureCodingBridge() }
}

public extension Defaults.Serializable where Self: Codable & NSSecureCoding & Defaults.PreferNSSecureCoding {
    static var bridge: Defaults.NSSecureCodingBridge<Self> { Defaults.NSSecureCodingBridge() }
}

public extension Defaults.Serializable where Self: Codable & RawRepresentable {
    static var bridge: Defaults.RawRepresentableCodableBridge<Self> { Defaults.RawRepresentableCodableBridge() }
}

public extension Defaults.Serializable where Self: Codable & RawRepresentable & Defaults.PreferRawRepresentable {
    static var bridge: Defaults.RawRepresentableBridge<Self> { Defaults.RawRepresentableBridge() }
}

public extension Defaults.Serializable where Self: RawRepresentable {
    static var bridge: Defaults.RawRepresentableBridge<Self> { Defaults.RawRepresentableBridge() }
}

public extension Defaults.Serializable where Self: NSSecureCoding {
    static var bridge: Defaults.NSSecureCodingBridge<Self> { Defaults.NSSecureCodingBridge() }
}

public extension Defaults.CollectionSerializable where Element: Defaults.Serializable {
    static var bridge: Defaults.CollectionBridge<Self> { Defaults.CollectionBridge() }
}

public extension Defaults.SetAlgebraSerializable where Element: Defaults.Serializable & Hashable {
    static var bridge: Defaults.SetAlgebraBridge<Self> { Defaults.SetAlgebraBridge() }
}

public extension Dictionary {
    func copyWithout(key: Key) -> Self {
        var m = self

        m.removeValue(forKey: key)
        return m
    }

    func copyWith(key: Key, value: Value) -> Self {
        var m = self

        m[key] = value
        return m
    }
}

public extension Encodable {
    var json: String? {
        (try? JSONEncoder().encode(self))?.s
    }
}

public extension Decodable {
    func fromJSON(_ json: String) -> Self? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

public extension FlattenSequence {
    var arr: [Element] { Array(self) }
}

public extension Binding<Int> {
    var f: Binding<Float> {
        Binding<Float>(get: { wrappedValue.f }, set: { wrappedValue = $0.intround })
    }
}
