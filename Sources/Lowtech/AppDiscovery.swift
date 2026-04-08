import AppKit
import Combine
import Foundation
import System

// MARK: - MetaQuery

public struct MetaQuery {
    public init(scopes: [String], queryString: String, handler: @escaping ([NSMetadataItem]) -> Void) {
        let q = NSMetadataQuery()
        q.searchScopes = scopes
        q.predicate = NSPredicate(fromMetadataQueryString: queryString)

        q.start()
        query = q
        observer = NotificationCenter.default.publisher(for: NSNotification.Name.NSMetadataQueryDidFinishGathering)
            .sink { notification in
                guard let query = notification.object as? NSMetadataQuery, q == query,
                      let items = query.results as? [NSMetadataItem]
                else {
                    return
                }
                q.stop()
                handler(items)
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

/// Queries Spotlight for all installed apps on disk and returns them via callback.
///
/// The caller must hold onto the returned `MetaQuery` until the handler fires,
/// otherwise the query observer will be deallocated.
///
///     var appQuery: MetaQuery?
///     appQuery = queryInstalledApps { apps in
///         print(apps.map(\.name))
///         appQuery = nil
///     }
public func queryInstalledApps(handler: @escaping ([InstalledApp]) -> Void) -> MetaQuery {
    MetaQuery(
        scopes: [NSMetadataQueryLocalComputerScope],
        queryString: "kMDItemContentTypeTree == 'com.apple.application-bundle'"
    ) { items in
        let apps = items.compactMap { item -> InstalledApp? in
            guard let dict = item.values(forAttributes: INSTALLED_APP_META_ATTRS),
                  let pathString = dict[NSMetadataItemPathKey] as? String,
                  let path = pathString.existingFilePath,
                  let bundleIdentifier = dict[NSMetadataItemCFBundleIdentifierKey] as? String
            else { return nil }

            let name = dict[NSMetadataItemDisplayNameKey] as? String ?? path.name.string
            return InstalledApp(
                path: path,
                name: name,
                useCount: dict["kMDItemUseCount"] as? Int ?? 0,
                bundleIdentifier: bundleIdentifier
            )
        }
        handler(apps)
    }
}
