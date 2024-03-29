//
//  Util.swift
//  rcmd
//
//  Created by Alin Panaitiu on 09.11.2021.
//

import Cocoa
import Combine
import Defaults
import Foundation

@inline(__always)
public func timeSince(_ date: Date) -> TimeInterval {
    date.timeIntervalSinceNow * -1
}

@inline(__always)
public func timeUntil(_ date: Date) -> TimeInterval {
    date.timeIntervalSinceNow
}

public func cap<T: Comparable>(_ number: T, minVal: T, maxVal: T) -> T {
    max(min(number, maxVal), minVal)
}

// MARK: - Formatting

public struct Formatting: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(padding)
        hasher.combine(decimals)
    }

    let decimals: Int
    let padding: Int
}

// MARK: - ObservableSettings

@MainActor
public protocol ObservableSettings: AnyObject {
    var observers: Set<AnyCancellable> { get set }
    var apply: Bool { get set }

    func initObservers()
}

// MARK: - SettingTransformer

public struct SettingTransformer<Value, Transformed> {
    public init(to: @escaping (Value) -> Transformed, from: ((Transformed) -> Value)? = nil) {
        self.to = to
        self.from = from
    }

    public init(to: KeyPath<Value, Transformed>, from: KeyPath<Transformed, Value>? = nil) {
        self.to = { v in v[keyPath: to] }
        if let from {
            self.from = { v in v[keyPath: from] }
        } else {
            self.from = nil
        }
    }

    public let to: (Value) -> Transformed
    public let from: ((Transformed) -> Value)?

    public static func to(_ k: KeyPath<Value, Transformed>) -> Self {
        Self(to: k)
    }
}

public extension ObservableSettings {
    func withoutApply(_ action: () -> Void) {
        apply = false
        action()
        apply = true
    }

    func bind<Value>(_ key: Defaults.Key<Value>, property: ReferenceWritableKeyPath<Self, Value>, publisher: KeyPath<Self, Published<Value>.Publisher>? = nil, debounce: RunLoop.SchedulerTimeType.Stride? = nil) {
        let onSettingChange: (Defaults.KeyChange<Value>) -> Void = { [weak self] change in
            guard let self else { return }
            withoutApply {
                self[keyPath: property] = change.newValue
            }
        }

        if let debounce {
            Defaults.publisher(key)
                .debounce(for: debounce, scheduler: RunLoop.main)
                .sink(receiveValue: onSettingChange).store(in: &observers)
        } else {
            Defaults.publisher(key)
                .receive(on: RunLoop.main)
                .sink(receiveValue: onSettingChange).store(in: &observers)
        }

        guard let publisher else { return }

        let onChange: (Value) -> Void = { [weak self] val in
            guard let self, apply else { return }
            Defaults.withoutPropagation {
                Defaults[key] = val
            }
        }

        if let debounce {
            self[keyPath: publisher]
                .debounce(for: debounce, scheduler: RunLoop.main)
                .sink(receiveValue: onChange).store(in: &observers)
        } else {
            self[keyPath: publisher]
                .receive(on: RunLoop.main)
                .sink(receiveValue: onChange).store(in: &observers)
        }
    }

    func bind<Value, Transformed>(
        _ key: Defaults.Key<Value>,
        property: ReferenceWritableKeyPath<Self, Transformed>,
        publisher: KeyPath<Self, Published<Transformed>.Publisher>? = nil,
        debounce: RunLoop.SchedulerTimeType.Stride? = nil,
        transformer: SettingTransformer<Value, Transformed>
    ) {
        let onSettingChange: (Defaults.KeyChange<Value>) -> Void = { [weak self] change in
            guard let self else { return }
            withoutApply {
                self[keyPath: property] = transformer.to(change.newValue)
            }
        }

        if let debounce {
            Defaults.publisher(key)
                .debounce(for: debounce, scheduler: RunLoop.main)
                .sink(receiveValue: onSettingChange).store(in: &observers)
        } else {
            Defaults.publisher(key)
                .receive(on: RunLoop.main)
                .sink(receiveValue: onSettingChange).store(in: &observers)
        }

        guard let publisher else { return }

        let onChange: (Transformed) -> Void = { [weak self] val in
            guard let self, apply, let transform = transformer.from else { return }
            Defaults.withoutPropagation {
                Defaults[key] = transform(val)
            }
        }

        if let debounce {
            self[keyPath: publisher]
                .debounce(for: debounce, scheduler: RunLoop.main)
                .sink(receiveValue: onChange).store(in: &observers)
        } else {
            self[keyPath: publisher]
                .receive(on: RunLoop.main)
                .sink(receiveValue: onChange).store(in: &observers)
        }
    }
}

// MARK: - Setting

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public class Setting<Value: Defaults.Serializable> {
    public init(_ key: Defaults.Key<Value>) {
        self.key = key
        storage = Storage(initialValue: Defaults[key])
        observer = Defaults.publisher(key)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                storage.value = $0.newValue
                storage.oldValue = $0.oldValue
            }
    }

    public typealias Publisher = AnyPublisher<Defaults.KeyChange<Value>, Never>

    public var wrappedValue: Value {
        get { storage.value }
        set {
            storage.oldValue = storage.value
            storage.value = newValue
            Defaults.withoutPropagation {
                Defaults[key] = newValue
            }
        }
    }

    private class Storage {
        init(initialValue: Value) {
            value = initialValue
        }

        var value: Value
        var oldValue: Value?
    }

    private var observer: Cancellable?
    private var storage: Storage
    private let key: Defaults.Key<Value>
}

@discardableResult
@inline(__always) public func mainThread<T>(_ action: () -> T) -> T {
    guard !Thread.isMainThread else {
        return action()
    }
    return DispatchQueue.main.sync { action() }
}

@inline(__always) public func mainAsync(_ action: @escaping () -> Void) {
    guard !Thread.isMainThread else {
        action()
        return
    }
    DispatchQueue.main.async { action() }
}

@discardableResult
public func mainAsyncAfter(ms: Int, _ action: @escaping () -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    let workItem = DispatchWorkItem {
        action()
    }
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)

    return workItem
}

@discardableResult
public func asyncAfter(ms: Int, _ action: @escaping () -> Void) -> DispatchWorkItem {
    let workItem = DispatchWorkItem(block: action)
    asyncAfter(ms: ms, workItem)

    return workItem
}

public extension DispatchWorkItem {
    func wait(for timeout: TimeInterval) -> DispatchTimeoutResult {
        let result = wait(timeout: .now() + timeout)
        if result == .timedOut {
            cancel()
            return .timedOut
        }
        return .success
    }
}

@discardableResult
public func asyncNow(timeout _: TimeInterval? = nil, _ action: @escaping () -> Void) -> DispatchWorkItem {
    let workItem = DispatchWorkItem(block: action)

    DispatchQueue.global().async(execute: workItem)
    return workItem
}

public func asyncAfter(ms: Int, _ action: DispatchWorkItem) {
    let deadline = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(ms * 1_000_000))

    DispatchQueue.global().asyncAfter(deadline: deadline, execute: action)
}

public func createWindow(
    _ identifier: String,
    controller: inout NSWindowController?,
    screen: NSScreen? = nil,
    show: Bool = true,
    backgroundColor: NSColor? = .clear,
    level: NSWindow.Level = .normal,
    fillScreen: Bool = false,
    stationary: Bool = false
) {
    mainThread {
        guard let mainStoryboard = NSStoryboard.main else { return }

        if controller == nil {
            controller = mainStoryboard
                .instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? NSWindowController
        }

        if let wc = controller {
            if let screen, let w = wc.window {
                w.setFrameOrigin(CGPoint(x: screen.frame.minX, y: screen.frame.minY))
                if fillScreen {
                    w.setFrame(screen.frame, display: false)
                }
            }

            if let window = wc.window {
                window.level = level
                window.isOpaque = false
                window.backgroundColor = backgroundColor
                if stationary {
                    window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling, .fullScreenNone]
                    window.sharingType = .none
                    window.ignoresMouseEvents = true
                    window.setAccessibilityRole(.popover)
                    window.setAccessibilitySubrole(.unknown)
                }
                if show {
                    wc.showWindow(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}

public func createTransition(
    duration: TimeInterval,
    type: CATransitionType,
    subtype: CATransitionSubtype = .fromTop,
    start: Float = 0.0,
    end: Float = 1.0,
    easing: CAMediaTimingFunction = .easeOutQuart
) -> CATransition {
    let transition = CATransition()
    transition.duration = duration
    transition.type = type
    transition.subtype = subtype
    transition.startProgress = start
    transition.endProgress = end
    transition.timingFunction = easing
    return transition
}

public func mapNumber<T: Numeric & Comparable & FloatingPoint>(_ number: T, fromLow: T, fromHigh: T, toLow: T, toHigh: T) -> T {
    if fromLow == fromHigh {
        print("fromLow and fromHigh are both equal to \(fromLow)")
        return number
    }

    if number >= fromHigh {
        return toHigh
    } else if number <= fromLow {
        return toLow
    } else if toLow < toHigh {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    } else {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    }
}

public extension Double {
    func map(from: (Double, Double), to: (Double, Double)) -> Double {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    func map(from: (Double, Double), to: (Double, Double), gamma: Double) -> Double {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
}

public extension Float {
    func map(from: (Float, Float), to: (Float, Float)) -> Float {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    func map(from: (Float, Float), to: (Float, Float), gamma: Float) -> Float {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
}

public extension CGFloat {
    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> CGFloat {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat), gamma: CGFloat) -> CGFloat {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }
}

@inline(__always)
public func lerp(_ value: Double, min: Double, max: Double) -> Double {
    min + (max - min) * value
}

@inline(__always)
public func invlerp(_ value: Double, min: Double, max: Double) -> Double {
    max == min ? min : (value - min) / (max - min)
}

@inline(__always)
public func lerp(_ value: Float, min: Float, max: Float) -> Float {
    min + (max - min) * value
}

@inline(__always)
public func invlerp(_ value: Float, min: Float, max: Float) -> Float {
    max == min ? min : (value - min) / (max - min)
}

@inline(__always)
public func lerp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    min + (max - min) * value
}

@inline(__always)
public func invlerp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    max == min ? min : (value - min) / (max - min)
}

@inline(__always)
public func lerpGamma22(_ value: Double, min: Double, max: Double) -> Double {
    let normalizedValue = invlerp(value, min: min, max: max)
    return pow(normalizedValue, 2.2) * (max - min) + min
}

@inline(__always)
public func lerpGamma(_ value: Double, min: Double, max: Double, gamma: Double) -> Double {
    let normalizedValue = invlerp(value, min: min, max: max)
    return pow(normalizedValue, gamma) * (max - min) + min
}

@inline(__always)
public func invlerpGamma22(_ interpolated: Double, min: Double, max: Double) -> Double {
    let normalizedValue = pow(invlerp(interpolated, min: min, max: max), 1.0 / 2.2)
    return normalizedValue * (max - min) + min
}

@inline(__always)
public func invlerpGamma(_ interpolated: Double, min: Double, max: Double, gamma: Double) -> Double {
    let normalizedValue = pow(invlerp(interpolated, min: min, max: max), 1.0 / gamma)
    return normalizedValue * (max - min) + min
}

public let NO_SHADOW: NSShadow = {
    let s = NSShadow()
    s.shadowColor = .clear
    s.shadowOffset = .zero
    s.shadowBlurRadius = 0
    return s
}()

// MARK: - IndexedCollection

public struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection where Base.Element: Hashable {
    public typealias Index = Base.Index
    public typealias Element = (index: Index, element: Base.Element) where Base.Element: Hashable

    public var startIndex: Index { base.startIndex }
    public var endIndex: Index { base.endIndex }

    public func index(after i: Index) -> Index {
        base.index(after: i)
    }

    public func index(before i: Index) -> Index {
        base.index(before: i)
    }

    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        base.index(i, offsetBy: distance)
    }

    public subscript(position: Index) -> Element {
        (index: position, element: base[position])
    }

    let base: Base
}

public extension RandomAccessCollection where Element: Hashable {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}

public func promptForWorkingDirectoryPermission(
    message: String = "Choose your working directory",
    prompt: String = "Choose",
    initialPath: URL = FileManager.default.homeDirectoryForCurrentUser.deletingLastPathComponent(),
    defaultsKey: Defaults.Key<Data?>? = nil
) -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.message = message
    openPanel.prompt = prompt
    openPanel.resolvesAliases = true
    openPanel.allowedFileTypes = ["none"]
    openPanel.allowsOtherFileTypes = false
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.directoryURL = initialPath

    let result = openPanel.runModal()
    guard let url = openPanel.urls.first else { return nil }

    switch result {
    case .cancel, .abort:
        return nil
    case .OK:
        saveBookmarkData(for: url, defaultsKey: defaultsKey)
        return url
    default:
        return nil
    }
}

public func promptForFilePermission(
    message: String = "Choose a file",
    prompt: String = "Choose",
    initialPath: URL = FileManager.default.homeDirectoryForCurrentUser,
    defaultsKey: Defaults.Key<Data?>? = nil
) -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.message = message
    openPanel.prompt = prompt
    openPanel.resolvesAliases = true
    openPanel.allowsOtherFileTypes = false
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = true
    openPanel.directoryURL = initialPath

    let result = openPanel.runModal()
    guard let url = openPanel.urls.first else { return nil }

    switch result {
    case .cancel, .abort:
        return nil
    case .OK:
        saveBookmarkData(for: url, defaultsKey: defaultsKey)
        return url
    default:
        return nil
    }
}

public func saveBookmarkData(for workDir: URL, defaultsKey: Defaults.Key<Data?>? = nil) {
    do {
        let bookmarkData = try workDir.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

        Defaults[defaultsKey ?? Defaults.Key("\(workDir.path.sha1)-BookmarkData")] = bookmarkData
    } catch {
        err("Failed to save bookmark data for \(workDir): \(error)")
    }
}

public func restoreFileAccess(for workDir: URL? = nil, defaultsKey: Defaults.Key<Data?>? = nil) -> URL? {
    guard let bookmarkData = Defaults[defaultsKey ?? Defaults.Key("\(workDir?.path.sha1 ?? "")-BookmarkData")] else { return nil }

    do {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        if isStale {
            debug("Bookmark is stale, need to save a new one... ")
            saveBookmarkData(for: url, defaultsKey: defaultsKey)
        }
        return url
    } catch {
        err("Error resolving bookmark: \(error)")
        return nil
    }
}

public extension URL {
    @discardableResult
    func withScopedAccess<T>(fileChoiceMessage: String = "Choose a file", _ action: (URL) -> T) -> T? {
        guard let url = restoreFileAccess(for: self) ?? promptForFilePermission(message: fileChoiceMessage, initialPath: self), url.startAccessingSecurityScopedResource()
        else { return nil }

        let result = action(url)
        url.stopAccessingSecurityScopedResource()
        return result
    }
}

public let SWIFTUI_PREVIEW = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
