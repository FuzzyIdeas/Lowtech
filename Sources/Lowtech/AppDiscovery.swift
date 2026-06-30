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
    /// When `handlerQueue` is non-nil the handler runs on it (off the notifying
    /// run loop) while query updates stay disabled, then updates are re-enabled /
    /// the query stopped back on the main run loop. Use it when the handler does
    /// expensive per-item work (e.g. `value(forAttribute:)`, a synchronous XPC
    /// round-trip to the metadata server): on the notifying run loop that work
    /// can stall the app for tens of seconds (App Hang). Default nil keeps the
    /// historical synchronous-on-notification-thread behaviour.
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

        q.start()
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
                if let handlerQueue {
                    // Keep updates disabled across the off-thread handler so the
                    // frozen result set can't mutate under it, then re-enable /
                    // stop back on the notifying (main) run loop once it's done.
                    handlerQueue.async {
                        handler(items)
                        DispatchQueue.main.async {
                            if live { q.enableUpdates() } else { q.stop() }
                        }
                    }
                } else {
                    if live {
                        q.enableUpdates()
                    } else {
                        q.stop()
                    }
                    handler(items)
                }
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
        // Pull each bundle's attributes (a synchronous XPC per item to the
        // metadata server) off the run loop the query notifies on: on the main
        // run loop this stalled the app for tens of seconds with many bundles or
        // a busy index (App Hang). MetaQuery keeps updates disabled across this,
        // so reading the frozen snapshot off-thread is safe; we hop back to main
        // to deliver, matching the historical delivery thread.
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
