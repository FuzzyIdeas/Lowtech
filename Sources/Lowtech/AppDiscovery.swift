import AppKit
import Combine
import Foundation
import System

// MARK: - MetaQuery

public struct MetaQuery {
    /// When `live` is false the query stops after the initial gather (one
    /// shot, the historical behaviour). When `live` is true it keeps
    /// running and re-invokes `handler` with the full result set every time
    /// Spotlight picks up matching items being added, removed or changed,
    /// so callers see installs/moves/deletes without polling. The caller
    /// must keep the `MetaQuery` alive for as long as updates are wanted.
    /// When `handlerQueue` is non-nil the whole query runs on an operation queue
    /// backed by it: the query is started there, its notifications are posted
    /// there, and the handler runs there while query updates stay disabled. The
    /// main thread never touches the query. Use it when the handler does
    /// expensive per-item work (e.g. `value(forAttribute:)`, a synchronous XPC
    /// round-trip to the metadata server), or when the query may be started
    /// while the metadata server is slow: `startQuery` waits for the server, and
    /// on the main thread that wait was an App Hang of 30 s and more (CLING-1R).
    /// Default nil keeps the historical behaviour: started on the calling
    /// thread, notified and handled on the main run loop.
    public init(scopes: [String], queryString: String, live: Bool = false, valueListAttributes: [String] = [], handlerQueue: DispatchQueue? = nil, handler: @escaping ([NSMetadataItem]) -> Void) {
        let q = NSMetadataQuery()
        q.searchScopes = scopes
        q.predicate = NSPredicate(fromMetadataQueryString: queryString)
        // Prefetch these attributes during the gather phase so reading them
        // later via `value(forAttribute:)` / `values(forAttributes:)` hits the
        // query's resident cache instead of a synchronous per-item XPC roundtrip
        // to the metadata server. Without this, extracting attributes for
        // hundreds of app bundles on the main thread (the run loop the query
        // notifies on) can stall it for tens of seconds. Must be set before
        // `start()`.
        if !valueListAttributes.isEmpty {
            q.valueListAttributes = valueListAttributes
        }

        // NSMetadataQuery allows `startQuery` only on its operation queue or on
        // the main thread, and posts its notifications on that queue when one is
        // set. A serial queue over `handlerQueue` keeps the start, the
        // notifications, the handler and the stop on one thread that isn't main.
        let operationQueue: OperationQueue? = handlerQueue.map { handlerQueue in
            let oq = OperationQueue()
            oq.name = "fyi.lowtech.MetaQuery"
            oq.maxConcurrentOperationCount = 1
            oq.underlyingQueue = handlerQueue
            return oq
        }
        q.operationQueue = operationQueue

        query = q
        observer = NotificationCenter.default.publisher(for: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: q)
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name.NSMetadataQueryDidUpdate, object: q))
            .sink { notification in
                guard let query = notification.object as? NSMetadataQuery, q == query else {
                    return
                }
                // Pause live updates while copying out of the results proxy
                // so the array can't mutate mid-enumeration.
                q.disableUpdates()
                let items = query.results.compactMap { $0 as? NSMetadataItem }
                if handlerQueue != nil {
                    // Already on the query's operation queue: keep updates
                    // disabled across the handler so the frozen result set
                    // can't mutate under it, then re-enable or stop here.
                    handler(items)
                    if live { q.enableUpdates() } else { q.stop() }
                } else {
                    if live {
                        q.enableUpdates()
                    } else {
                        q.stop()
                    }
                    handler(items)
                }
            }

        if let operationQueue {
            operationQueue.addOperation { q.start() }
        } else {
            q.start()
        }
    }

    public let query: NSMetadataQuery
    public let observer: Cancellable
}

// MARK: - InstalledApp

public struct InstalledApp {
    public init(path: FilePath, name: String, useCount: Int, bundleIdentifier: String) {
        self.path = path
        self.name = name
        self.useCount = useCount
        self.bundleIdentifier = bundleIdentifier
    }

    public let path: FilePath
    public let name: String
    public let useCount: Int
    public let bundleIdentifier: String

    public var url: URL { path.url }
}

// MARK: - App discovery

public let APP_DIRS = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]

private let INSTALLED_APP_META_ATTRS = [
    NSMetadataItemDisplayNameKey,
    "kMDItemUseCount",
    NSMetadataItemPathKey,
    NSMetadataItemCFBundleIdentifierKey,
]

public extension FilePath {
    /// Whether the path sits inside a Trash directory (`~/.Trash`, a
    /// volume-level `.Trashes`). Spotlight keeps indexing app bundles after
    /// they're trashed, so app discovery has to drop them explicitly: a
    /// trashed app is not "installed" and must never be offered for launch.
    var inTrash: Bool {
        components.contains { $0.string.hasPrefix(".Trash") }
    }
}

/// Queries Spotlight for all installed apps on disk and returns them via callback.
///
/// The caller must hold onto the returned `MetaQuery` until the handler fires,
/// otherwise the query observer will be deallocated. With `live: true` the
/// handler keeps firing as Spotlight notices apps being installed, moved or
/// deleted, so keep the `MetaQuery` alive for the whole process.
///
///     var appQuery: MetaQuery?
///     appQuery = queryInstalledApps { apps in
///         print(apps.map(\.name))
///         appQuery = nil
///     }
private let installedAppsQueue = DispatchQueue(label: "fyi.lowtech.installedAppsQuery", qos: .userInitiated)

public func queryInstalledApps(live: Bool = false, handler: @escaping ([InstalledApp]) -> Void) -> MetaQuery {
    MetaQuery(
        scopes: [NSMetadataQueryLocalComputerScope],
        queryString: "kMDItemContentTypeTree == 'com.apple.application-bundle'",
        live: live,
        valueListAttributes: INSTALLED_APP_META_ATTRS,
        // Run the whole query off the main thread: starting it waits for the
        // metadata server (CLING-1R), and each bundle's attributes are a
        // synchronous XPC per item. On the main thread either one stalled the
        // app for tens of seconds with many bundles or a busy index (App Hang).
        // MetaQuery keeps updates disabled across the handler, so reading the
        // frozen snapshot here is safe; we hop back to main to deliver, matching
        // the historical delivery thread.
        handlerQueue: installedAppsQueue
    ) { items in
        let apps = items.compactMap { item -> InstalledApp? in
            // Read attributes with the singular `value(forAttribute:)`, NOT the
            // plural `values(forAttributes:)`. With `valueListAttributes` set, the
            // plural API builds a dictionary and inserts every requested attribute;
            // when one resolves to nil (e.g. kMDItemPath for an item mid-delete
            // during a live update, or a bundle whose path the index can't resolve)
            // it inserts nil and throws "object cannot be nil", crashing the app
            // (hit re-entrantly while an AppleScript run loop drained a live update).
            // The singular API returns an optional the guard skips, and still reads
            // from the prefetch cache (measured ~3.5x faster than no prefetch), so
            // this keeps the no-per-item-XPC win without the crash.
            guard let pathString = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let path = pathString.existingFilePath,
                  !path.inTrash,
                  let bundleIdentifier = item.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String
            else { return nil }

            let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String ?? path.name.string
            return InstalledApp(
                path: path,
                name: name,
                useCount: item.value(forAttribute: "kMDItemUseCount") as? Int ?? 0,
                bundleIdentifier: bundleIdentifier
            )
        }
        // Deliver on main: the off-thread work above is done, and callers (e.g.
        // rcmd's main-actor app processing) expect the historical main delivery.
        DispatchQueue.main.async { handler(apps) }
    }
}
