import CoreServices
import Foundation

public typealias FSEventsEventID = FSEventStreamEventId

public extension FSEventsEventID {
    static var now: FSEventsEventID { FSEventsEventID(kFSEventStreamEventIdSinceNow) }
}

public struct FSEventsCreateFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let none = FSEventsCreateFlags([])
    public static let useCFTypes = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagUseCFTypes))
    public static let noDefer = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagNoDefer))
    public static let watchRoot = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagWatchRoot))
    public static let ignoreSelf = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagIgnoreSelf))
    public static let fileEvents = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagFileEvents))
    public static let markSelf = FSEventsCreateFlags(rawValue: UInt32(kFSEventStreamCreateFlagMarkSelf))
}

public struct FSEventsEventFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let none = FSEventsEventFlags([])
    public static let mustScanSubDirs = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagMustScanSubDirs))
    public static let userDropped = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagUserDropped))
    public static let kernelDropped = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagKernelDropped))
    public static let eventIdsWrapped = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagEventIdsWrapped))
    public static let historyDone = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagHistoryDone))
    public static let rootChanged = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagRootChanged))
    public static let mount = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagMount))
    public static let unmount = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagUnmount))
    public static let itemCreated = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemCreated))
    public static let itemRemoved = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRemoved))
    public static let itemInodeMetaMod = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemInodeMetaMod))
    public static let itemRenamed = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRenamed))
    public static let itemModified = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemModified))
    public static let itemFinderInfoMod = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemFinderInfoMod))
    public static let itemChangeOwner = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemChangeOwner))
    public static let itemXattrMod = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemXattrMod))
    public static let itemIsFile = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsFile))
    public static let itemIsDir = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsDir))
    public static let itemIsSymlink = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsSymlink))
    public static let ownEvent = FSEventsEventFlags(rawValue: UInt32(kFSEventStreamEventFlagOwnEvent))
}

public struct FSEventsEvent {
    public var path: String
    public var flag: FSEventsEventFlags?
    public var ID: FSEventsEventID?
}

public final class FSEventStream {
    private var stream: FSEventStreamRef?
    private let handler: (FSEventsEvent) -> Void

    public init(
        pathsToWatch: [String],
        sinceWhen: FSEventsEventID,
        latency: TimeInterval,
        flags: FSEventsCreateFlags,
        handler: @escaping (FSEventsEvent) -> Void
    ) throws {
        self.handler = handler

        let allFlags = flags.union(.useCFTypes).rawValue

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, eventIDs in
            guard let info else { return }
            let owner = Unmanaged<FSEventStream>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            for i in 0 ..< numEvents {
                let path = i < paths.count ? paths[i] : ""
                let event = FSEventsEvent(
                    path: path,
                    flag: FSEventsEventFlags(rawValue: eventFlags[i]),
                    ID: eventIDs[i]
                )
                owner.handler(event)
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch as CFArray,
            sinceWhen,
            latency,
            allFlags
        ) else {
            throw FSEventsError.streamCreateFailed
        }
        self.stream = stream
    }

    public func setDispatchQueue(_ queue: DispatchQueue) {
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
    }

    public func start() throws {
        guard let stream else { throw FSEventsError.streamCreateFailed }
        guard FSEventStreamStart(stream) else { throw FSEventsError.streamStartFailed }
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
    }

    public func invalidate() {
        guard let stream else { return }
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        if stream != nil { invalidate() }
    }
}

public enum FSEventsError: Error {
    case streamCreateFailed
    case streamStartFailed
}

public enum FSEvents {
    private static var watchers: [ObjectIdentifier: FSEventStream] = [:]

    public static func startWatching(
        paths: [String],
        for id: ObjectIdentifier,
        sinceWhen: FSEventsEventID = .now,
        latency: TimeInterval = 0,
        flags: FSEventsCreateFlags = [.noDefer, .fileEvents],
        with handler: @escaping (FSEventsEvent) -> Void
    ) throws {
        assert(Thread.isMainThread)
        stopWatching(for: id)

        let s = try FSEventStream(
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
        guard let s = watchers[id] else { return }
        s.stop()
        s.invalidate()
        watchers[id] = nil
    }
}
