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

@inline(__always) @inlinable
public func timeSince(_ date: Date) -> TimeInterval {
    date.timeIntervalSinceNow * -1
}

@inline(__always) @inlinable
public func timeUntil(_ date: Date) -> TimeInterval {
    date.timeIntervalSinceNow
}

@inline(__always) @inlinable
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
            Defaults[key] = val
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
            Defaults[key] = transform(val)
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

public func debouncer<T>(in observers: inout Set<AnyCancellable>, throttle: Bool = false, every duration: RunLoop.SchedulerTimeType.Stride? = nil, _ action: @escaping (T) -> Void) -> PassthroughSubject<T, Never> {
    let subject = PassthroughSubject<T, Never>()

    if let duration {
        if !throttle {
            subject
                .debounce(for: duration, scheduler: RunLoop.main)
                .sink { action($0) }
                .store(in: &observers)
        } else {
            subject
                .throttle(for: duration, scheduler: RunLoop.main, latest: true)
                .sink { action($0) }
                .store(in: &observers)
        }
    } else {
        subject
            .sink { action($0) }
            .store(in: &observers)
    }

    return subject
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

@inline(__always) @inlinable public func lerp(_ value: Double, min: Double, max: Double) -> Double {
    min + (max - min) * value
}

@inline(__always) @inlinable public func invlerp(_ value: Double, min: Double, max: Double) -> Double {
    max == min ? min : (value - min) / (max - min)
}

@inline(__always) @inlinable public func lerp(_ value: Float, min: Float, max: Float) -> Float {
    min + (max - min) * value
}

@inline(__always) @inlinable public func invlerp(_ value: Float, min: Float, max: Float) -> Float {
    max == min ? min : (value - min) / (max - min)
}

@inline(__always) @inlinable public func lerp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    min + (max - min) * value
}

@inline(__always) @inlinable public func invlerp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    max == min ? min : (value - min) / (max - min)
}

public extension BinaryInteger {
    @inline(__always) @inlinable
    func map(from: (Self, Self), to: (Self, Self)) -> Self {
        Self(lerp(invlerp(d, min: from.0.d, max: from.1.d), min: to.0.d, max: to.1.d))
    }

    @inline(__always) @inlinable
    func map(from: (Self, Self), to: (Self, Self), gamma: Double) -> Self {
        Self(lerp(pow(invlerp(d, min: from.0.d, max: from.1.d), 1.0 / gamma), min: to.0.d, max: to.1.d))
    }

    @inline(__always) @inlinable
    func capped(between minVal: Self, and maxVal: Self) -> Self {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
}

public extension Double {
    @inline(__always) @inlinable
    func map(from: (Double, Double), to: (Double, Double)) -> Double {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func map(from: (Double, Double), to: (Double, Double), gamma: Double) -> Double {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func capped(between minVal: Double, and maxVal: Double) -> Double {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
}

public extension Float {
    @inline(__always) @inlinable
    func map(from: (Float, Float), to: (Float, Float)) -> Float {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func map(from: (Float, Float), to: (Float, Float), gamma: Float) -> Float {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func capped(between minVal: Float, and maxVal: Float) -> Float {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
}

public extension CGFloat {
    @inline(__always) @inlinable
    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> CGFloat {
        lerp(invlerp(self, min: from.0, max: from.1), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func map(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat), gamma: CGFloat) -> CGFloat {
        lerp(pow(invlerp(self, min: from.0, max: from.1), 1.0 / gamma), min: to.0, max: to.1)
    }

    @inline(__always) @inlinable
    func capped(between minVal: CGFloat, and maxVal: CGFloat) -> CGFloat {
        cap(self, minVal: minVal, maxVal: maxVal)
    }
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
    openPanel.allowedContentTypes = [.folder]
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

import UniformTypeIdentifiers

public extension URL {
    @discardableResult
    func withScopedAccess<T>(fileChoiceMessage: String = "Choose a file", _ action: (URL) -> T) -> T? {
        guard let url = restoreFileAccess(for: self) ?? promptForFilePermission(message: fileChoiceMessage, initialPath: self), url.startAccessingSecurityScopedResource()
        else { return nil }

        let result = action(url)
        url.stopAccessingSecurityScopedResource()
        return result
    }

    func fetch(delegate: URLSessionDataDelegate? = nil) async throws -> Data {
        let request = URLRequest(url: self, cachePolicy: .useProtocolCachePolicy)
        let (data, response) = try await downloader.data(for: request, delegate: delegate)

        // Store data in cache
        if downloadCache.cachedResponse(for: request) == nil {
            downloadCache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        }

        // Move file to target location
        return data
    }

    func download(to url: URL? = nil, type: UTType? = nil, delegate: URLSessionDataDelegate? = nil) async throws -> URL {
        let request = URLRequest(url: self, cachePolicy: .useProtocolCachePolicy)
        let (data, response) = try await downloader.data(for: request, delegate: delegate)

        // Store data in cache
        if downloadCache.cachedResponse(for: request) == nil {
            downloadCache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        }

        // Move file to target location
        let destURL = url ?? FileManager.default.temporaryDirectory.appendingPathComponent(absoluteString.sha1 + (type != nil ? ".\(type!.preferredFilenameExtension!)" : ""))
        FileManager.default.createFile(atPath: destURL.path, contents: data)
        return destURL
    }
}

public let SWIFTUI_PREVIEW = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

let downloadCache: URLCache = {
    let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let diskCacheURL = cachesURL.appendingPathComponent("DownloadCache")
    let cache = URLCache(memoryCapacity: 100_000_000, diskCapacity: 1_000_000_000, directory: diskCacheURL)
    debug("Cache path: \(diskCacheURL.path)")
    return cache
}()

let downloader: URLSession = {
    let config = URLSessionConfiguration.default
    config.urlCache = downloadCache
    return URLSession(configuration: config)
}()

import CryptoKit
import IOKit

func IOServiceProperty<T>(_ service: io_service_t, _ key: String) -> T? {
    guard let cfProp = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)
    else {
        return nil
    }
    guard let value = cfProp.takeRetainedValue() as? T else {
        cfProp.release()
        return nil
    }
    return value
}

func generateAPIKey() -> String {
    var r = SystemRandomNumberGenerator()
    let serialNumberData = Data(r.next().toUInt8Array() + r.next().toUInt8Array() + r.next().toUInt8Array() + r.next().toUInt8Array())
    let hash = SHA256.hash(data: serialNumberData)
        .prefix(20).data.base64()
        .replacingOccurrences(of: "/", with: ".")
        .replacingOccurrences(of: "+", with: ".")
    return hash
}

func getSerialNumberHash() -> String? {
    let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

    guard platformExpert > 0 else {
        return nil
    }

    defer { IOObjectRelease(platformExpert) }

    guard let serialNumber: String = IOServiceProperty(platformExpert, kIOPlatformSerialNumberKey) else {
        return nil
    }

    guard let serialNumberData = serialNumber.trimmed.data(using: .utf8, allowLossyConversion: true) else {
        return nil
    }
    let hash = SHA256.hash(data: serialNumberData)
        .prefix(20).data.base64()
        .replacingOccurrences(of: "/", with: ".")
        .replacingOccurrences(of: "+", with: ".")

    return hash
}

public let SERIAL_NUMBER_HASH = getSerialNumberHash() ?? generateAPIKey()

public func restart() {
    guard CommandLine.arguments.count == 1 else {
        exit(1)
    }
    do {
        try exec(arg0: Bundle.main.executablePath!, args: [])
    } catch {
        err("Failed to restart: \(error)")
    }
    exit(0)
}

public func restartOnCrash() {
    NSSetUncaughtExceptionHandler { _ in restart() }
    signal(SIGABRT) { _ in restart() }
    signal(SIGILL) { _ in restart() }
    signal(SIGSEGV) { _ in restart() }
    signal(SIGFPE) { _ in restart() }
    signal(SIGBUS) { _ in restart() }
    signal(SIGPIPE) { _ in restart() }
    signal(SIGTRAP) { _ in restart() }
}


import var Darwin.EINVAL
import var Darwin.ERANGE
import func Darwin.strerror_r

public func stringerror(_ code: Int32) -> String {
    var cap = 64
    while cap <= 16 * 1024 {
        var buf = [Int8](repeating: 0, count: cap)
        let err = strerror_r(code, &buf, buf.count)
        if err == EINVAL {
            return "unknown error \(code)"
        }
        if err == ERANGE {
            cap *= 2
            continue
        }
        if err != 0 {
            return "fatal: strerror_r: \(err)"
        }
        return "\(String(cString: buf)) (\(code))"
    }
    return "fatal: strerror_r: ERANGE"
}

public func exec(arg0: String, args: [String]) throws -> Never {
    let args = CStringArray([arg0] + args)

    guard execv(arg0, args.cArray) != -1 else {
        throw POSIXError.execv(executable: arg0, errno: errno)
    }

    fatalError("Impossible if execv succeeded")
}

public enum POSIXError: LocalizedError {
    case execv(executable: String, errno: Int32)

    public var errorDescription: String? {
        switch self {
        case let .execv(executablePath, errno):
            "execv failed: \(stringerror(errno)): \(executablePath)"
        }
    }
}

private final class CStringArray {
    /// Creates an instance from an array of strings.
    public init(_ array: [String]) {
        cArray = array.map { $0.withCString { strdup($0) } } + [nil]
    }

    deinit {
        for case let element? in cArray {
            free(element)
        }
    }

    /// The null-terminated array of C string pointers.
    public let cArray: [UnsafeMutablePointer<Int8>?]

}
