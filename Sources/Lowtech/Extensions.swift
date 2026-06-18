import AppKit
import Combine
import Foundation
import os
import QuickLookThumbnailing
import SwiftUI

private let logger = Logger(subsystem: lowtechLogSubsystem, category: "Extensions")

infix operator =~: ComparisonPrecedence
infix operator !~: ComparisonPrecedence

public func =~ (input: String, pattern: String) -> Bool {
    guard let regex = try? Regex(pattern) else { return false }
    return input.contains(regex)
}
public func !~ (input: String, pattern: String) -> Bool {
    !(input =~ pattern)
}

public func =~ (input: String, regex: Regex<String>) -> Bool {
    input.contains(regex)
}
public func !~ (input: String, regex: Regex<String>) -> Bool {
    !(input =~ regex)
}
public func =~ (regex: Regex<String>, input: String) -> Bool {
    input.contains(regex)
}
public func !~ (regex: Regex<String>, input: String) -> Bool {
    !(regex =~ input)
}
public func =~ (input: String, regex: Regex<Substring>) -> Bool {
    input.contains(regex)
}
public func !~ (input: String, regex: Regex<Substring>) -> Bool {
    !(input =~ regex)
}
public func =~ (regex: Regex<Substring>, input: String) -> Bool {
    input.contains(regex)
}
public func !~ (regex: Regex<Substring>, input: String) -> Bool {
    !(regex =~ input)
}

public extension Regex {
    func replaceAll(in string: String, with replacement: String) -> String {
        string.replacing(self, with: replacement)
    }
}

// implementation of the `/` operator for FilePath and String that always returns a FilePath using .appending
public func / (lhs: FilePath, rhs: String) -> FilePath {
    lhs.appending(rhs)
}
public func / (lhs: FilePath, rhs: FilePath.Component) -> FilePath {
    lhs.appending(rhs)
}
public func / (lhs: FilePath, rhs: FilePath) -> FilePath {
    lhs.appending(rhs.string)
}
public func / (lhs: String, rhs: FilePath.Component) -> FilePath {
    FilePath(lhs).appending(rhs)
}
public func / (lhs: String, rhs: FilePath) -> FilePath {
    FilePath(lhs).appending(rhs.string)
}
public func / (lhs: String, rhs: String) -> FilePath {
    FilePath(lhs).appending(rhs)
}

public prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}

public extension String {
    var r: Regex<String>? {
        try? Regex(self)
    }
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

infix operator ?!: NilCoalescingPrecedence

public func ?! <K: Hashable, V>(_ dict: [K: V]?, _ dict2: [K: V]) -> [K: V] {
    guard let dict, !dict.isEmpty else {
        return dict2
    }
    return dict
}

public func ?! (_ str: String?, _ str2: String) -> String {
    guard let str, !str.isEmpty else {
        return str2
    }
    return str
}

public func ?! <T: BinaryInteger>(_ num: T?, _ num2: T) -> T {
    guard let num, num != 0 else {
        return num2
    }
    return num
}

public func ?! (_ num: Double?, _ num2: Double) -> Double {
    guard let num, num != 0 else {
        return num2
    }
    return num
}

public func ?! (_ num: Float?, _ num2: Float) -> Float {
    guard let num, num != 0 else {
        return num2
    }
    return num
}

public func ?! (_ num: CGFloat?, _ num2: CGFloat) -> CGFloat {
    guard let num, num != 0 else {
        return num2
    }
    return num
}

public func ?! <T: BinaryInteger>(_ num: T, _ num2: T) -> T {
    num != 0 ? num : num2
}

public func ?! (_ num: Double, _ num2: Double) -> Double {
    num != 0 ? num : num2
}

public func ?! (_ num: Float, _ num2: Float) -> Float {
    num != 0 ? num : num2
}

public func ?! (_ num: CGFloat, _ num2: CGFloat) -> CGFloat {
    num != 0 ? num : num2
}

public func ?! (_ svc: io_service_t?, _ svc2: io_service_t?) -> io_service_t? {
    guard let svc, svc != 0 else {
        return svc2
    }
    return svc
}

public func ?! (_ svc: io_service_t?, _ svc2: io_service_t) -> io_service_t {
    guard let svc, svc != 0 else {
        return svc2
    }
    return svc
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
    @inline(__always) @inlinable var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) @inlinable var i32: Int32? {
        Int32(self)
    }

    @inline(__always) @inlinable var d: Double? {
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
    @inline(__always) @inlinable var i: Int {
        self ? 1 : 0
    }

    #if os(macOS)
        @inline(__always) @inlinable var state: NSControl.StateValue {
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
                options: cursor
                    ? [.mouseEnteredAndExited, .cursorUpdate, .activeInActiveApp]
                    : [.mouseEnteredAndExited, .activeInActiveApp],
                owner: owner ?? self,
                userInfo: nil
            )
            addTrackingArea(area)
        }

        @inline(__always) @inlinable func transition(
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
            let point = CGPoint(
                x: horizontally ? rect.midX - frame.width / 2 : frame.origin.x,
                y: vertically ? rect.midY - frame.height / 2 : frame.origin.y
            )
            setFrameOrigin(point)
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

    public extension Double {
        var evenInt: Int {
            let x = intround
            return x + x % 2
        }
    }

    public extension Float {
        var evenInt: Int {
            let x = intround
            return x + x % 2
        }
    }

    public extension CGFloat {
        var evenInt: Int {
            let x = intround
            return x + x % 2
        }
    }

    public extension NSSize {
        var s: String { "\(width.i)×\(height.i)" }
        var area: CGFloat { width * height }
        func scaled(by factor: Double) -> CGSize {
            CGSize(width: (width * factor).evenInt, height: (height * factor).evenInt)
        }
    }

    extension NSSize: @retroactive Comparable {
        public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
            (lhs.width < rhs.width && lhs.height <= rhs.height)
                || (lhs.width <= rhs.width && lhs.height < rhs.height)
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
            animator().setFrame(NSRect(origin: self.frame.origin, size: self.frame.size), display: true)
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
    @inline(__always) @inlinable func rounded(to scale: Int) -> Double {
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

    @inline(__always) @inlinable var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) @inlinable var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) @inlinable var d: Double {
        Double(self)
    }

    @inline(__always) @inlinable var i: Int {
        Int(self)
    }

    @inline(__always) @inlinable var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) @inlinable var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) @inlinable var i8: Int8 {
        Int8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var i16: Int16 {
        Int16(self)
    }

    @inline(__always) @inlinable var i32: Int32 {
        Int32(self)
    }

    @inline(__always) @inlinable var intround: Int {
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
    @inline(__always) @inlinable func rounded(to scale: Int) -> Double {
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

    @inline(__always) @inlinable var ns: NSNumber {
        NSNumber(value: self)
    }

    @inline(__always) @inlinable var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) @inlinable var f: Float {
        Float(self)
    }

    @inline(__always) @inlinable var i: Int {
        Int(self)
    }

    @inline(__always) @inlinable var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) @inlinable var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) @inlinable var i8: Int8 {
        Int8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var i16: Int16 {
        Int16(self)
    }

    @inline(__always) @inlinable var i32: Int32 {
        Int32(self)
    }

    @inline(__always) @inlinable var intround: Int {
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
            value
        } else {
            String(format: "%02x", self)
        }
    }
}

infix operator %%

extension UInt64 {
    func toUInt8Array() -> [UInt8] {
        [
            UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF),
            UInt8((self >> 32) & 0xFF), UInt8((self >> 40) & 0xFF), UInt8((self >> 48) & 0xFF), UInt8((self >> 56) & 0xFF),
        ]
    }
}

public extension BinaryInteger {
    @inline(__always) @inlinable
    static func %% (_ a: Self, _ n: Self) -> Self {
        precondition(n > 0, "modulus must be positive")
        let r = a % n
        return r >= 0 ? r : r + n
    }

    @inline(__always) @inlinable var ns: NSNumber {
        NSNumber(value: d)
    }

    @inline(__always) @inlinable var d: Double {
        Double(self)
    }

    @inline(__always) @inlinable var cg: CGFloat {
        CGFloat(self)
    }

    @inline(__always) @inlinable var f: Float {
        Float(self)
    }

    @inline(__always) @inlinable var u: UInt {
        UInt(max(self, 0))
    }

    @inline(__always) @inlinable var u8: UInt8 {
        UInt8(max(self, 0))
    }

    @inline(__always) @inlinable var u16: UInt16 {
        UInt16(max(self, 0))
    }

    @inline(__always) @inlinable var u32: UInt32 {
        UInt32(max(self, 0))
    }

    @inline(__always) @inlinable var u64: UInt64 {
        UInt64(max(self, 0))
    }

    @inline(__always) @inlinable var i: Int {
        Int(self)
    }

    @inline(__always) @inlinable var i8: Int8 {
        Int8(self)
    }

    @inline(__always) @inlinable var i16: Int16 {
        Int16(self)
    }

    @inline(__always) @inlinable var i32: Int32 {
        Int32(cap(Int(self), minVal: Int(Int32.min), maxVal: Int(Int32.max)))
    }

    @inline(__always) @inlinable var i64: Int64 {
        Int64(self)
    }

    @inline(__always) @inlinable var s: String {
        String(self)
    }

    func asPercentage(of value: Self, decimals: UInt8 = 2) -> String {
        "\(((d / value.d) * 100.0).str(decimals: decimals))%"
    }
}

import System

public extension String {
    var ns: NSString {
        self as NSString
    }

    var filePath: FilePath? {
        guard !isEmpty, count <= 4096 else { return nil }
        return FilePath(trimmedPath.ns.expandingTildeInPath)
    }

    var trimmedPath: String {
        trimmingCharacters(in: ["\"", "'", "\n", "\t", " ", "{", "}", ","])
    }

    var url: URL? {
        guard contains(":"), count <= 10240 else { return nil }
        return URL(string: trimmedPath)
    }

    var fileURL: URL? {
        guard count <= 10240 else { return nil }
        let str = trimmedPath
        guard str.isNotEmpty, str != "file://" else { return nil }

        return str.starts(with: "file:") ? URL(string: str) : URL(fileURLWithPath: str)
    }

    var existingFilePath: FilePath? {
        guard let path = filePath, path.exists else { return nil }
        return path
    }

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

    @inline(__always) @inlinable var d: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.doubleValue
    }

    @inline(__always) @inlinable var f: Float? {
        Float(replacingOccurrences(of: ",", with: "."))
        // NumberFormatter.shared.number(from: self)?.floatValue
    }

    @inline(__always) @inlinable var u: UInt? {
        UInt(self)
    }

    @inline(__always) @inlinable var u8: UInt8? {
        UInt8(self)
    }

    @inline(__always) @inlinable var u16: UInt16? {
        UInt16(self)
    }

    @inline(__always) @inlinable var u32: UInt32? {
        UInt32(self)
    }

    @inline(__always) @inlinable var u64: UInt64? {
        UInt64(self)
    }

    @inline(__always) @inlinable var i: Int? {
        Int(self)
    }

    @inline(__always) @inlinable var i8: Int8? {
        Int8(self)
    }

    @inline(__always) @inlinable var i16: Int16? {
        Int16(self)
    }

    @inline(__always) @inlinable var i32: Int32? {
        Int32(self)
    }

    @inline(__always) @inlinable var i64: Int64? {
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

public extension OptionSet {
    func hasElements(from otherSet: Self) -> Bool {
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
    @inline(__always) @inlinable var d: Double {
        Double(self)
    }

    @inline(__always) @inlinable var i: Int {
        Int(self)
    }

    @inline(__always) @inlinable var u8: UInt8 {
        UInt8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var u16: UInt16 {
        UInt16(self)
    }

    @inline(__always) @inlinable var u32: UInt32 {
        UInt32(self)
    }

    @inline(__always) @inlinable var i8: Int8 {
        Int8(cap(intround, minVal: 0, maxVal: 255))
    }

    @inline(__always) @inlinable var i16: Int16 {
        Int16(self)
    }

    @inline(__always) @inlinable var i32: Int32 {
        Int32(self)
    }

    @inline(__always) @inlinable var intround: Int {
        rounded().i
    }

    @inline(__always) @inlinable var ns: NSNumber {
        NSNumber(value: Float(self))
    }
}

public extension [UInt8] {
    var data: Data {
        Data(self)
    }
}

public extension PrefixSequence<SHA256Digest> {
    var data: Data {
        map { $0 }.data
    }
}

public extension Data {
    var s: String? { String(data: self, encoding: .utf8) }

    func base64(urlSafe: Bool = false) -> String {
        str(hex: false, base64: true, urlSafe: urlSafe)
    }

    func hex(urlSafe: Bool = false, separator: String = " ") -> String {
        str(hex: true, base64: false, urlSafe: urlSafe, separator: separator)
    }

    func urlSafeString(separator: String = " ") -> String {
        str(hex: false, base64: false, urlSafe: true, separator: separator)
    }

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
    @inline(__always) @inlinable var trimmed: String {
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

public extension Character {
    var s: String {
        String(self)
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
    /// Applies the given transform if the given condition evaluates to `true`.viv
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

    /// Drag modifier that writes real file URLs directly to NSPasteboard,
    /// bypassing SwiftUI's NSFilePromiseProvider which copies files to
    /// `~/Library/Caches/com.apple.SwiftUI.Drag-<UUID>/`.
    func onDragRealPath(_ fileURL: URL?, disabled: Bool = false, onDragStarted: (() -> Void)? = nil) -> some View {
        overlay(
            RealPathDragSource(fileURLs: [fileURL].compactMap { $0 }, disabled: disabled, onDragStarted: onDragStarted)
        )
    }

    func onDragRealPath(_ fileURLs: [URL], disabled: Bool = false, onDragStarted: (() -> Void)? = nil) -> some View {
        overlay(
            RealPathDragSource(fileURLs: fileURLs, disabled: disabled, onDragStarted: onDragStarted)
        )
    }
}

// MARK: - SwiftUI .draggable() symlink swizzle

/// Swizzles SwiftUI's drag internals so that `.draggable()` provides the real
/// file path instead of copying to `~/Library/Caches/com.apple.SwiftUI.Drag-<UUID>/`.
///
/// Two swizzles work together:
/// 1. `NSFileManager.copyItemAtURL:toURL:error:` creates a symlink instead of a copy
/// 2. `NSPasteboardItem.setString:forType:` and `setData:forType:` resolve the
///    symlink back to the real path before writing to the pasteboard
///
/// Call once at app launch (e.g. in `applicationDidFinishLaunching`).
public func swizzleDraggableToRealPath() {
    // Swizzle 1: copy -> symlink
    if let original = class_getInstanceMethod(FileManager.self, NSSelectorFromString("copyItemAtURL:toURL:error:")),
       let swizzled = class_getInstanceMethod(FileManager.self, #selector(FileManager.lt_copyItem(at:to:error:)))
    {
        method_exchangeImplementations(original, swizzled)
    }

    // Swizzle 2: resolve symlink in pasteboard string
    if let original = class_getInstanceMethod(NSPasteboardItem.self, #selector(NSPasteboardItem.setString(_:forType:))),
       let swizzled = class_getInstanceMethod(NSPasteboardItem.self, #selector(NSPasteboardItem.lt_setString(_:forType:)))
    {
        method_exchangeImplementations(original, swizzled)
    }

    // Swizzle 3: resolve symlink in pasteboard data
    if let original = class_getInstanceMethod(NSPasteboardItem.self, #selector(NSPasteboardItem.setData(_:forType:))),
       let swizzled = class_getInstanceMethod(NSPasteboardItem.self, #selector(NSPasteboardItem.lt_setData(_:forType:)))
    {
        method_exchangeImplementations(original, swizzled)
    }
}

@available(*, deprecated, renamed: "swizzleDraggableToRealPath")
public func swizzleDraggableCopyToSymlink() {
    swizzleDraggableToRealPath()
}

import ObjectiveC

private let swiftUIDragMarker = "com.apple.SwiftUI.Drag"

extension FileManager {
    @objc dynamic func lt_copyItem(at srcURL: NSURL, to dstURL: NSURL, error errorPtr: NSErrorPointer) -> Bool {
        if let dstStr = dstURL.absoluteString, dstStr.contains(swiftUIDragMarker) {
            do {
                try createSymbolicLink(at: dstURL as URL, withDestinationURL: srcURL as URL)
                return true
            } catch {}
        }
        return lt_copyItem(at: srcURL, to: dstURL, error: errorPtr)
    }
}

extension NSPasteboardItem {
    @objc dynamic func lt_setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        if type == .fileURL, string.contains(swiftUIDragMarker),
           let resolved = resolveSwiftUIDragSymlink(string)
        {
            return lt_setString(resolved, forType: type)
        }
        return lt_setString(string, forType: type)
    }

    @objc dynamic func lt_setData(_ data: Data, forType type: NSPasteboard.PasteboardType) -> Bool {
        if type == .fileURL,
           let string = String(data: data, encoding: .utf8),
           string.contains(swiftUIDragMarker),
           let resolved = resolveSwiftUIDragSymlink(string)
        {
            return lt_setData(Data(resolved.utf8), forType: type)
        }
        return lt_setData(data, forType: type)
    }
}

private func resolveSwiftUIDragSymlink(_ urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)
    else { return nil }
    return URL(fileURLWithPath: dest).absoluteString
}

// MARK: - AppKit file drag source (bypasses SwiftUI's NSFilePromiseProvider cache copy)

public struct RealPathDragSource: NSViewRepresentable {
    public func makeNSView(context: Context) -> RealPathDragSourceView {
        RealPathDragSourceView(fileURLs: fileURLs, disabled: disabled, onDragStarted: onDragStarted)
    }

    public func updateNSView(_ nsView: RealPathDragSourceView, context: Context) {
        nsView.fileURLs = fileURLs
        nsView.disabled = disabled
        nsView.onDragStarted = onDragStarted
    }

    let fileURLs: [URL]
    var disabled = false
    var onDragStarted: (() -> Void)?

}

public class RealPathDragSourceView: NSView, NSDraggingSource {
    init(fileURLs: [URL], disabled: Bool, onDragStarted: (() -> Void)?) {
        self.fileURLs = fileURLs
        self.disabled = disabled
        self.onDragStarted = onDragStarted
        super.init(frame: .zero)
        loadThumbnails()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override public func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }

    override public func mouseDragged(with event: NSEvent) {
        guard !disabled, !fileURLs.isEmpty, let dragOrigin else {
            super.mouseDragged(with: event)
            return
        }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - dragOrigin.x
        let dy = current.y - dragOrigin.y
        guard dx * dx + dy * dy > 16 else {
            super.mouseDragged(with: event)
            return
        }
        self.dragOrigin = nil

        onDragStarted?()

        // All files go on the pasteboard, but only show up to 2 drag images
        let maxVisible = 2
        let totalCount = fileURLs.count

        var draggingItems = [NSDraggingItem]()
        for (i, url) in fileURLs.enumerated() {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)

            let item = NSDraggingItem(pasteboardWriter: pasteboardItem)

            if i < maxVisible {
                // Show drag image for first 2 files (with count badge on the last visible one)
                let showBadge = (i == maxVisible - 1 && totalCount > maxVisible)
                let image = dragImage(for: url, badge: showBadge ? totalCount : nil)
                let imageSize = image.size
                let offset = CGFloat(i) * 4
                let frame = NSRect(
                    origin: NSPoint(
                        x: (bounds.width - imageSize.width) / 2 + offset,
                        y: (bounds.height - imageSize.height) / 2 - offset
                    ),
                    size: imageSize
                )
                item.setDraggingFrame(frame, contents: image)
            } else {
                // Hidden items: 1x1 transparent, still on the pasteboard
                let pixel = NSImage(size: NSSize(width: 1, height: 1))
                item.setDraggingFrame(NSRect(x: 0, y: 0, width: 1, height: 1), contents: pixel)
            }
            draggingItems.append(item)
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        guard !fileURLs.isEmpty, !disabled else { return nil }
        return frame.contains(point) ? self : nil
    }

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    var disabled: Bool
    var onDragStarted: (() -> Void)?

    var fileURLs: [URL] {
        didSet {
            guard fileURLs != oldValue else { return }
            loadThumbnails()
        }
    }

    private static let thumbSize = CGSize(width: 128, height: 128)

    private var dragOrigin: NSPoint?
    private var cachedThumbnails: [URL: NSImage] = [:]

    private func loadThumbnails() {
        cachedThumbnails.removeAll()

        // Only generate thumbnails for the first 2 files (max visible in drag)
        let toLoad = fileURLs.prefix(2)
        guard !toLoad.isEmpty else { return }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for fileURL in toLoad {
            let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: Self.thumbSize, scale: scale, representationTypes: .all)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
                DispatchQueue.main.async {
                    guard let self, self.fileURLs.contains(fileURL) else { return }
                    if let cgImage = representation?.cgImage {
                        self.cachedThumbnails[fileURL] = NSImage(cgImage: cgImage, size: Self.thumbSize)
                    }
                }
            }
        }
    }

    private func dragImage(for url: URL, badge: Int? = nil) -> NSImage {
        let thumb: NSImage
        if let cached = cachedThumbnails[url] {
            thumb = cached
        } else {
            thumb = NSWorkspace.shared.icon(forFile: url.path)
            thumb.size = Self.thumbSize
        }

        let filename = url.lastPathComponent
        let labelHeight: CGFloat = 22
        let padding: CGFloat = 6
        let cornerRadius: CGFloat = 18
        let totalSize = NSSize(width: Self.thumbSize.width, height: Self.thumbSize.height + labelHeight + padding)

        return NSImage(size: totalSize, flipped: true) { _ in
            NSGraphicsContext.saveGraphicsState()
            let thumbRect = NSRect(origin: .zero, size: Self.thumbSize)
            let path = NSBezierPath(roundedRect: thumbRect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.addClip()
            thumb.draw(in: thumbRect, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()

            // Count badge (top-right corner)
            if let badge {
                let badgeStr = "\(badge)" as NSString
                let badgeFont = NSFont.systemFont(ofSize: 13, weight: .bold)
                let badgeAttrs: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: NSColor.white]
                let badgeSize = badgeStr.size(withAttributes: badgeAttrs)
                let badgeW = max(badgeSize.width + 10, 24)
                let badgeH: CGFloat = 22
                let badgeRect = NSRect(x: Self.thumbSize.width - badgeW - 2, y: 2, width: badgeW, height: badgeH)
                NSColor.systemBlue.setFill()
                NSBezierPath(roundedRect: badgeRect, xRadius: badgeH / 2, yRadius: badgeH / 2).fill()
                let textOrigin = NSPoint(x: badgeRect.midX - badgeSize.width / 2, y: badgeRect.midY - badgeSize.height / 2)
                badgeStr.draw(at: textOrigin, withAttributes: badgeAttrs)
            }

            // Filename label
            NSGraphicsContext.saveGraphicsState()
            let labelRect = NSRect(x: 0, y: Self.thumbSize.height + padding, width: totalSize.width, height: labelHeight)
            let bgRect = labelRect.insetBy(dx: -2, dy: -2)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
            NSColor(white: 0, alpha: 0.65).setFill()
            bgPath.fill()

            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byTruncatingMiddle
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white,
                .paragraphStyle: style,
            ]
            let textRect = labelRect.insetBy(dx: 4, dy: 2)
            (filename as NSString).draw(in: textRect, withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()

            return true
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

public func ~= (lhs: Regex<some Any>, rhs: String) -> Bool {
    (try? lhs.firstMatch(in: rhs)) != nil
}

public func ~= <T: Equatable>(lhs: [T], rhs: T) -> Bool {
    lhs.contains(rhs)
}

public func ~= <T: Equatable & Hashable>(lhs: Set<T>, rhs: T) -> Bool {
    lhs.contains(rhs)
}

public extension Sequence where Element: Identifiable {
    func without(id: Element.ID) -> [Element] {
        filter { $0.id != id }
    }
}

public extension Set where Element: Identifiable {
    func without(id: Element.ID) -> Set<Element> {
        filter { $0.id != id }
    }
}

public extension Sequence where Element: Equatable & Hashable {
    func with(_ element: Element) -> [Element] {
        self + [element]
    }

    func with(_ elements: [Element]) -> [Element] {
        self + elements
    }

    func without(_ element: Element) -> [Element] {
        filter { $0 != element }
    }

    func without(_ elements: Set<Element>) -> [Element] {
        filter { !elements.contains($0) }
    }

    func without(_ elements: [Element]) -> [Element] {
        filter { !elements.contains($0) }
    }

    var uniqued: [Element] { Set(self).arr }
    var set: Set<Element> { Set(self) }

    func uniqued(by keyPath: KeyPath<Element, some Hashable>) -> [Element] {
        var seen = Set<AnyHashable>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }

    func replacing(_ element: Element, with newElement: Element) -> [Element] {
        map { $0 == element ? newElement : $0 }
    }

//    func without(_ elements: [Element]) -> [Element] {
//        let elSet = Set(elements)
//        return filter { !elSet.contains($0) }
//    }
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

// MARK: - Bool + Comparable

extension Bool: @retroactive Comparable {
    public static func < (lhs: Bool, rhs: Bool) -> Bool {
        !lhs && rhs
    }
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
                e1[keyPath: keyPath] < e2[keyPath: keyPath]
            case .reverse:
                e1[keyPath: keyPath] > e2[keyPath: keyPath]
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
    @MainActor
    static func oneway(getter: @escaping () -> Value) -> Binding {
        Binding(get: getter, set: { _ in })
    }

    @MainActor
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

public extension SetAlgebra {
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
    var version: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundlePath)
    }

    var name: String {
        infoDictionary?["CFBundleName"] as? String
            ?? executableURL?.deletingPathExtension().lastPathComponent
            ?? bundleURL.lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }

    var isMenuBarApp: Bool {
        (object(forInfoDictionaryKey: "LSUIElement") as? Bool) ?? false
    }
}

public extension NSRunningApplication {
    var isRegular: Bool {
        // The RUNNING activation policy is dynamic: an app can call
        // `setActivationPolicy` at runtime (e.g. a menubar/.accessory app that
        // flips to .regular when it opens a real window). It's a cheap
        // in-process read, so it must NOT be cached — caching froze the
        // first-seen value and made dynamically-promoted apps look permanently
        // accessory. (The on-disk *bundle* policy never changes and stays
        // worth caching elsewhere; this isn't that.)
        activationPolicy == .regular
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
        let attr: [FileAttributeKey: Any]? = withTimeout(5, name: "binaryMatchesLaunchDate(\(path))") {
            try fm.attributesOfItem(atPath: path)
        }
        guard let attr else {
            logger.warning("binaryMatchesLaunchDate: could not read attributes of \(path, privacy: .public), assuming match")
            return true
        }

        let binaryModifiedDate = attr[.modificationDate] as? Date
        guard let launchDate, let binaryModifiedDate else {
            logger.warning("binaryMatchesLaunchDate: \(path, privacy: .public) missing launchDate or modificationDate, assuming match")
            return true
        }

        let ignored = ignoredBinaryDates[path] == binaryModifiedDate
        let matches = binaryModifiedDate <= launchDate || ignored
        let launchDateStr = "\(launchDate)"
        let binaryDateStr = "\(binaryModifiedDate)"
        logger
            .info(
                "binaryMatchesLaunchDate: path=\(path, privacy: .public) launchDate=\(launchDateStr, privacy: .public) binaryModifiedDate=\(binaryDateStr, privacy: .public) ignored=\(ignored, privacy: .public) matches=\(matches, privacy: .public)"
            )
        return matches
    }
}

var ignoredBinaryDates: [String: Date] = [:]
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
            userInfo: [NSLocalizedDescriptionKey: stringerror(err)]
        )
    }
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
    var prettyJSON: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(self))?.s
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

var SAFE_FILENAME_REGEX: Regex = try! Regex(#"[\/:{}<>*|$#&^;'"`\x00-\x09\x0B-\x0C\x0E-\x1F\n\t]"#)

public extension String {
    var safeFilename: String {
        replacing(SAFE_FILENAME_REGEX, with: { _ in "_" })
    }

    subscript(_ idx: Int) -> String {
        switch idx {
        case 0:
            String(first!)
        case (count - 1) ... Int.max:
            String(last!)
        case Int.min ..< 0:
            String(suffix(-idx).first!)
        default:
            String(prefix(idx + 1).last!)
        }
    }

    subscript(_ range: Range<Int>) -> String {
        String(prefix(range.upperBound).suffix(range.upperBound - range.lowerBound))
    }
}

// MARK: - Text + AdditiveArithmetic

extension Text: @retroactive AdditiveArithmetic {
    public static func - (lhs: Text, rhs: Text) -> Text {
        lhs + rhs
    }

    public static var zero: Text {
        Text("")
    }
}

public extension NSVisualEffectView.Material {
    static let osd = NSVisualEffectView.Material(rawValue: 26) ?? .hudWindow
}

public extension DispatchQueue {
    @discardableResult
    func asyncAfter(ms: Int, _ action: @escaping () -> Void) -> DispatchWorkItem {
        let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

        let workItem = DispatchWorkItem {
            action()
        }
        asyncAfter(deadline: deadline, execute: workItem)

        return workItem
    }
}

public extension NSAppearance {
    static var dark: NSAppearance? { NSAppearance(named: .darkAqua) }
    static var light: NSAppearance? { NSAppearance(named: .aqua) }
    static var vibrantDark: NSAppearance? { NSAppearance(named: .vibrantDark) }
    static var vibrantLight: NSAppearance? { NSAppearance(named: .vibrantLight) }
}

import CryptoKit

public extension Data {
    var sha256: String {
        SHA256.hash(data: self).hexEncodedString()
    }
}

public extension NumberFormatter {
    static var int: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        formatter.localizesFormat = false
        formatter.usesGroupingSeparator = false
        formatter.hasThousandSeparators = false

        return formatter
    }
}

public extension FilePath {
    func relative(to: String) -> FilePath {
        guard let fp = to.filePath else { return self }

        var copy = self
        let _ = copy.removePrefix(fp)
        return copy
    }
    func relative(to fp: FilePath) -> FilePath {
        var copy = self
        let _ = copy.removePrefix(fp)
        return copy
    }

    var contentsSHA256: String? {
        guard let data = fm.contents(atPath: string) else {
            return nil
        }
        return SHA256.hash(data: data).hexEncodedString()
    }

    var sha256: String? {
        guard let data = string.data(using: .utf8, allowLossyConversion: true) else {
            return nil
        }
        return SHA256.hash(data: data).hexEncodedString()
    }

    var sha256WithTimestamp: String? {
        let string = "\(string)\(timestamp ?? 0)"
        guard let data = string.data(using: .utf8, allowLossyConversion: true) else {
            return nil
        }
        return SHA256.hash(data: data).hexEncodedString()
    }

    func hasExtension(from extensions: [String]) -> Bool {
        guard let ext = `extension`?.lowercased() else { return false }
        return extensions.contains(ext)
    }

    func withSize(width: Int, height: Int) -> FilePath {
        withSize(CGSize(width: width, height: height))
    }

    func withExtension(_ ext: String) -> FilePath {
        removingLastComponent().appending("\(stem!).\(ext)")
    }

    func withSize(_ size: CGSize) -> FilePath {
        removingLastComponent().appending("\(stem!.replacing(#/_\d+x\d+$/#, with: ""))_\(size.width.evenInt)x\(size.height.evenInt).\(`extension`!)")
    }

    func withFilters(_ filters: String...) -> FilePath {
        withFilters(filters)
    }

    func withFilters(_ filters: [String]) -> FilePath {
        let name = stem!.replacing(#/_\[.+\]$/#, with: "")
        let filterStr = filters.joined(separator: ",")
        return removingLastComponent().appending("\(name)_[\(filterStr)].\(`extension`!)")
    }

    @discardableResult
    func waitForFile(for seconds: TimeInterval) -> Bool {
        let path = string
        let sleepSeconds = seconds / 10

        for _ in 1 ... 10 {
            if fm.fileExists(atPath: path) {
                return true
            }
            Thread.sleep(forTimeInterval: sleepSeconds)
        }
        return false
    }

    var name: FilePath.Component { lastComponent ?? "Root" }
    var nameWithoutSize: String {
        "\(stem!.replacing(#/_\d+x\d+$/#, with: "")).\(`extension`!)"
    }

    var nameWithoutFilters: String {
        "\(stem!.replacing(#/_\[.+\]$/#, with: "")).\(`extension`!)"
    }

    var modificationDate: Date? {
        guard let attrs = try? fm.attributesOfItem(atPath: string),
              let date = attrs[.modificationDate] as? Date ?? attrs[.creationDate] as? Date
        else {
            return nil
        }
        return date
    }

    var timestamp: TimeInterval? {
        modificationDate?.timeIntervalSince1970
    }

    var nameWithHash: String {
        guard let stem, let ext = `extension`, let hash = sha256WithTimestamp else {
            return name.string
        }
        let name = stem.replacing(Self.trailingHashesPattern, with: "")
        return "\(name)_\(hash).\(ext)"
    }

    static let trailingHashesPattern = try! Regex(#"(_[a-f0-9]{64})+$"#)
    static let hashPattern = try! Regex(#"_([a-f0-9]{64})$"#)
    var nameWithoutHash: String {
        guard let stem else {
            return name.string
        }
        return stem.replacing(Self.hashPattern, with: ".")
    }
    var withoutHash: FilePath {
        guard let ext = `extension` else {
            return dir / "\(nameWithoutHash)"
        }
        return dir / "\(nameWithoutHash).\(ext)"
    }

    static var tmp = FilePath("/tmp")
    static var backups = FilePath.dir(URL.cachesDirectory.appendingPathComponent(Bundle.main.name, conformingTo: .directory).appendingPathComponent("backups", conformingTo: .directory).path, permissions: 0o777)

    static func dir(_ string: String, permissions: Int = 0o755) -> FilePath {
        dir(FilePath(string), permissions: permissions)
    }
    static func dir(_ path: FilePath, permissions: Int = 0o755) -> FilePath {
        path.mkdir(withIntermediateDirectories: true, permissions: permissions)
        return path
    }

    @discardableResult
    func mkdir(withIntermediateDirectories: Bool, permissions: Int = 0o755) -> Bool {
        guard !exists else { return true }
        do {
            try fm.createDirectory(atPath: string, withIntermediateDirectories: withIntermediateDirectories, attributes: [.posixPermissions: permissions])
        } catch {
            logger.error("Error creating directory '\(string)': \(error)")
            return false
        }
        return true
    }

    var dir: FilePath { removingLastComponent() }
    var url: URL { URL(filePath: self)! }
    var backupPath: FilePath? {
        FilePath.backups.appending(nameWithHash)
    }

    enum BackupOperation {
        case copy
        case move
    }

    @discardableResult
    func backup(path: FilePath? = nil, force: Bool = false, operation: BackupOperation = .move) -> FilePath? {
        guard let backupPath = path ?? backupPath else {
            return nil
        }

        guard exists else {
            logger.error("Path doesn't exist: \(string)")
            return nil
        }

        do {
            logger.debug("Backing up path \(shellString) to \(backupPath.shellString)")
            if backupPath.exists {
                guard force else { return backupPath }
                try backupPath.delete()
            }
            if operation == .copy {
                try copy(to: backupPath)
            } else {
                try move(to: backupPath)
            }
        } catch {
            print("Backup error", error)
            return nil
        }

        return backupPath
    }

    func restore(backupPath: FilePath? = nil, force: Bool = true) {
        guard let backupPath = backupPath ?? self.backupPath else {
            return
        }
        _ = try? backupPath.move(to: self, force: force)
    }

    func fileSize() -> Int? {
        guard exists else {
            return nil
        }
        let attr: [FileAttributeKey: Any]? = withTimeout(5, name: "fileSize(\(string))") {
            try fm.attributesOfItem(atPath: string)
        }
        guard let attr else {
            return nil
        }
        return (attr[FileAttributeKey.size] as? UInt64)?.i
    }

    var exists: Bool { fm.fileExists(atPath: string) }

    @discardableResult
    func move(to path: FilePath, force: Bool = false) throws -> FilePath {
        guard path != self else {
            logger.error("Trying to move path to itself: \(string)")
            return self
        }
        guard exists else {
            logger.error("Path doesn't exist: \(string)")
            return self
        }

        let path = path.isDir ? path.appending(name) : path

        if force { try path.delete() }
        logger.debug("Moving path \(shellString) to \(path.shellString)")
        try fm.moveItem(atPath: string, toPath: path.string)
        return path
    }

    var isDir: Bool {
        var isDirectory = ObjCBool(false)
        return fm.fileExists(atPath: string, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    @discardableResult
    func copy(to path: FilePath, force: Bool = false) throws -> FilePath {
        guard path != self else {
            logger.error("Trying to copy path to itself: \(string)")
            return self
        }
        guard exists else {
            logger.error("Path doesn't exist: \(string)")
            return self
        }

        let path = path.isDir ? path.appending(name) : path

        if force { try path.delete() }
        logger.debug("Copying path \(shellString) to \(path.shellString)")
        try fm.copyItem(atPath: string, toPath: path.string)
        return path
    }

    func delete() throws {
        guard exists else { return }
        logger.debug("Deleting path \(shellString)")
        try fm.removeItem(atPath: string)
    }

    func ls() -> [FilePath] {
        guard isDir else { return [] }
        return (try? fm.contentsOfDirectory(atPath: string))?.map { appending($0) } ?? []
    }

    var shellString: String { string.shellString }

    static let Applications = FilePath("/Applications")
    static let root = FilePath("/")
    static let home: FilePath = URL.homeDirectory.filePath!
}

public extension String {
    var shellString: String {
        guard let homeDirRegex = HOME_DIR_REGEX else {
            return replacingFirstOccurrence(of: NSHomeDirectory(), with: "~")
        }
        return replacing(homeDirRegex, with: { "~" + ($0.1 ?? "") })
    }
}
public extension URL {
    var shellString: String { isFileURL ? path.shellString : absoluteString }
}

let HOME_DIR_REGEX = (try? Regex("^/*?\(NSHomeDirectory())(/)?", as: (Substring, Substring?).self))?.ignoresCase()

public extension URL {
    var filePath: FilePath? { FilePath(self) }
    var existingFilePath: FilePath? { fm.fileExists(atPath: path) ? FilePath(self) : nil }
}

public let HOME = URL.homeDirectory.filePath!

public func focus() {
    if #available(macOS 14.0, *) {
        NSApp.activate(ignoringOtherApps: true)
        // TODO: Use the new API when it's
        // NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSRect + Hashable

extension NSRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

// MARK: - NSPoint + Hashable  // @retroactive Hashable

extension NSPoint: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

public extension NSSize {
    var aspectRatio: Double {
        width / height
    }
}

// MARK: - NSSize + Hashable  // @retroactive Hashable

extension NSSize: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

public enum LowtechFSEvents {
    public static func startWatching(
        paths: [String],
        for id: ObjectIdentifier,
        sinceWhen: EonilFSEventsEventID = .now,
        latency: TimeInterval = 0,
        flags: EonilFSEventsCreateFlags = [.noDefer, .fileEvents],
        with handler: @escaping (EonilFSEventsEvent) -> Void
    ) throws {
        assert(Thread.isMainThread)
        assert(watchers[id] == nil)

        let s = try EonilFSEventStream(
            pathsToWatch: paths,
            sinceWhen: sinceWhen,
            latency: latency,
            flags: flags,
            handler: handler
        )
        s.setDispatchQueue(DispatchQueue.main)
        try s.start()
        watchers[id] = s
    }
    public static func stopWatching(for id: ObjectIdentifier) {
        assert(Thread.isMainThread)
        // assert(watchers[id] != nil)
        guard let s = watchers[id] else { return }
        s.stop()
        s.invalidate()
        watchers[id] = nil
    }
}
private var watchers = [ObjectIdentifier: EonilFSEventStream]()
