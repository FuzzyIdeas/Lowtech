//
//  Util.swift
//  rcmd
//
//  Created by Alin Panaitiu on 09.11.2021.
//

import Atomics
import Cocoa
import Combine
import Defaults
import Foundation
import Path
import SwiftDate
import UserNotifications

@inline(__always)
public func localTimeSince(_ date: Date) -> TimeInterval {
    DateInRegion().convertTo(region: .local) - date.convertTo(region: .local)
}

@inline(__always)
public func localTimeUntil(_ date: Date) -> TimeInterval {
    date.convertTo(region: .local) - DateInRegion().convertTo(region: .local)
}

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

public func notify(identifier: String, title: String, body: String) {
    let sendNotification = { (nc: UNUserNotificationCenter) in
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        nc.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }

    let nc = UNUserNotificationCenter.current()
    nc.getNotificationSettings { settings in
        mainAsync {
            let enabled = settings.alertSetting == .enabled
            Defaults[.notificationsPermissionsGranted] = enabled
            guard enabled else {
                nc.requestAuthorization(options: [], completionHandler: { granted, _ in
                    guard granted else { return }
                    sendNotification(nc)
                })
                return
            }
            sendNotification(nc)
        }
    }
}

public func removeNotifications(withIdentifiers ids: [String]) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
}

// MARK: - Formatting

public struct Formatting: Hashable {
    // MARK: Public

    public func hash(into hasher: inout Hasher) {
        hasher.combine(padding)
        hasher.combine(decimals)
    }

    // MARK: Internal

    let decimals: Int
    let padding: Int
}

// MARK: - Atomic

@propertyWrapper
public struct Atomic<Value: AtomicValue> {
    // MARK: Lifecycle

    public init(wrappedValue: Value) {
        value = ManagedAtomic<Value>(wrappedValue)
    }

    // MARK: Public

    public var wrappedValue: Value {
        get { value.load(ordering: .relaxed) }
        set { value.store(newValue, ordering: .sequentiallyConsistent) }
    }

    // MARK: Internal

    var value: ManagedAtomic<Value>
}

@discardableResult
@inline(__always) public func mainThread<T>(_ action: () -> T) -> T {
    guard !Thread.isMainThread else {
        return action()
    }
    return DispatchQueue.main.sync { return action() }
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
public func asyncNow(timeout: TimeInterval? = nil, _ action: @escaping () -> Void) -> DispatchWorkItem {
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
            if let screen = screen, let w = wc.window {
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

public let NO_SHADOW: NSShadow = {
    let s = NSShadow()
    s.shadowColor = .clear
    s.shadowOffset = .zero
    s.shadowBlurRadius = 0
    return s
}()

// MARK: - IndexedCollection

public struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection where Base.Element: Hashable {
    // MARK: Public

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

    // MARK: Internal

    let base: Base
}

public extension RandomAccessCollection where Element: Hashable {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}

public func promptForWorkingDirectoryPermission(message: String = "Choose your working directory", prompt: String = "Choose", initialPath: String = "/Users", defaultsKey: Defaults.Key<Data?>? = nil) -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.message = message
    openPanel.prompt = prompt
    openPanel.resolvesAliases = true
    openPanel.allowedFileTypes = ["none"]
    openPanel.allowsOtherFileTypes = false
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.directoryURL = URL(fileURLWithPath: initialPath)

    openPanel.runModal()
    guard let url = openPanel.urls.first else { return nil }
    saveBookmarkData(for: url, defaultsKey: defaultsKey)

//    switch openPanel.runModal() {
//    case .cancel, .abort:
//        return nil
//    case .OK:
//        return openPanel.urls.first
//    }

    return url
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

public let SWIFTUI_PREVIEW = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
