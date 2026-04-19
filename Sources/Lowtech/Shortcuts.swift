import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - Model

public struct Shortcut: Codable, Hashable, Defaults.Serializable, Identifiable {
    public init(name: String, identifier: String, folder: String? = nil) {
        self.name = name
        self.identifier = identifier
        self.folder = folder
    }

    public var name: String
    public var identifier: String
    public var folder: String?

    public var id: String { identifier }

    public var url: URL {
        if let url = URL(string: identifier), url.scheme != nil {
            return url
        }
        guard let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://open-shortcut?id=\(encoded)")
        else {
            return URL(string: "shortcuts://")!
        }
        return url
    }
}

// MARK: - Fetching

/// Deadlock-safe helpers that talk to `/usr/bin/shortcuts`.
///
/// The key invariant is to read each pipe to EOF **before** calling
/// `waitUntilExit()`. When users have thousands of shortcuts, the child
/// process' stdout can exceed the ~64 KB pipe buffer — if we wait for
/// exit first, the child blocks on write and we deadlock forever.
public enum ShortcutsFetcher {
    public static func fetchFolderNames() -> [String] {
        runShortcutsList(args: ["list", "--folders"])
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    public static func fetchShortcuts(inFolder folder: String?) -> [Shortcut] {
        var args = ["list", "--show-identifiers"]
        if let folder { args += ["--folder-name", folder] }

        return runShortcutsList(args: args)
            .split(separator: "\n")
            .compactMap { line in
                let str = String(line)
                guard let openParen = str.lastIndex(of: "("),
                      let closeParen = str.lastIndex(of: ")") else { return nil }
                let identifier = String(str[str.index(after: openParen) ..< closeParen])
                let name = String(str[str.startIndex ..< openParen]).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !identifier.isEmpty else { return nil }
                return Shortcut(name: name, identifier: identifier, folder: folder)
            }
    }

    /// Fetches every shortcut (grouped by folder and ungrouped), deduplicated by identifier.
    public static func fetchAll() -> [Shortcut] {
        let folders = fetchFolderNames()
        var seen = Set<String>()
        var result: [Shortcut] = []

        for folder in folders {
            for shortcut in fetchShortcuts(inFolder: folder) {
                if seen.insert(shortcut.identifier).inserted {
                    result.append(shortcut)
                }
            }
        }
        for shortcut in fetchShortcuts(inFolder: nil) {
            if seen.insert(shortcut.identifier).inserted {
                result.append(shortcut)
            }
        }
        return result
    }

    /// Groups a flat shortcut list by folder. Ungrouped shortcuts come first,
    /// remaining folders are sorted alphabetically. Each group is sorted by name.
    public static func groupByFolder(_ shortcuts: [Shortcut]) -> [(folder: String?, shortcuts: [Shortcut])] {
        var grouped: [String?: [Shortcut]] = [:]
        for shortcut in shortcuts {
            grouped[shortcut.folder, default: []].append(shortcut)
        }
        let sorted = grouped.map { (folder: $0.key, shortcuts: $0.value.sorted { $0.name < $1.name }) }
        return sorted.sorted {
            switch ($0.folder, $1.folder) {
            case (nil, nil): false
            case (nil, _): true
            case (_, nil): false
            case let (a?, b?): a < b
            }
        }
    }

    /// Convenience `[String: [Shortcut]]` grouping for call sites that want a map.
    /// `nil` folders are collected under "Other".
    public static func mapByFolder(_ shortcuts: [Shortcut]) -> [String: [Shortcut]] {
        var map: [String: [Shortcut]] = [:]
        for shortcut in shortcuts {
            map[shortcut.folder ?? "Other", default: []].append(shortcut)
        }
        return map
    }

    /// Runs a shortcut with an optional file input/output path, returning the process.
    @discardableResult
    public static func run(identifier: String, inputPath: String? = nil, outputPath: String? = nil) -> Process? {
        guard !identifier.isEmpty else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        var args = ["run", identifier]
        if let inputPath, !inputPath.isEmpty { args += ["--input-path", inputPath] }
        if let outputPath, !outputPath.isEmpty { args += ["--output-path", outputPath] }
        process.arguments = args
        do {
            try process.run()
        } catch {
            return nil
        }
        return process
    }

    private static func runShortcutsList(args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        // Read the pipe to EOF BEFORE waiting for exit, otherwise the child
        // blocks on write once the ~64 KB buffer fills up.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Manager

/// Observable cache of installed Shortcuts. Apps typically use the `SHM` singleton.
///
/// Usage:
/// ```swift
/// // At app startup (on main thread):
/// SHM.startWatching()
/// SHM.fetch()
///
/// // In SwiftUI views:
/// @ObservedObject var shortcutsManager = SHM
/// ForEach(shortcutsManager.groupedByFolder, id: \.folder) { ... }
/// ```
public final class ShortcutsManager: ObservableObject {
    public init() {}

    public static let shared = ShortcutsManager()

    @Published public private(set) var shortcuts: [Shortcut] = []
    @Published public private(set) var hasFetched = false

    /// Hook invoked on the main thread after each successful refresh.
    /// Apps can use this to react to new shortcuts (e.g. detect a freshly installed helper).
    public var onRefresh: (([Shortcut]) -> Void)?

    /// How long before `fetch()` will refresh if called again. `force: true` bypasses this.
    public var cacheDuration: TimeInterval = 60

    // MARK: - Derived

    public var groupedByFolder: [(folder: String?, shortcuts: [Shortcut])] {
        ShortcutsFetcher.groupByFolder(shortcuts)
    }

    public var mapByFolder: [String: [Shortcut]] {
        ShortcutsFetcher.mapByFolder(shortcuts)
    }

    public func first(where predicate: (Shortcut) -> Bool) -> Shortcut? {
        shortcuts.first(where: predicate)
    }

    // MARK: - Fetch

    public func fetch(force: Bool = false) {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return
        }
        guard !isFetching else { return }
        isFetching = true

        DispatchQueue.global().async { [weak self] in
            let result = ShortcutsFetcher.fetchAll()
            DispatchQueue.main.async {
                guard let self else { return }
                self.shortcuts = result
                self.hasFetched = true
                self.lastFetch = Date()
                self.isFetching = false
                self.onRefresh?(result)
            }
        }
    }

    public func refetch() { fetch(force: true) }

    /// Invalidates the cache and triggers an immediate refresh.
    public func invalidateCache() {
        lastFetch = nil
        refetch()
    }

    // MARK: - Watch

    /// Starts watching the Shortcuts database for changes. Safe to call multiple times.
    /// Must be called on the main thread.
    public func startWatching() {
        guard !isWatching else { return }
        let shortcutsDir = "\(NSHomeDirectory())/Library/Shortcuts"
        guard FileManager.default.fileExists(atPath: shortcutsDir) else { return }

        let dbPath = "\(shortcutsDir)/Shortcuts.sqlite"
        let walPath = "\(shortcutsDir)/Shortcuts.sqlite-wal"
        do {
            try LowtechFSEvents.startWatching(
                paths: [dbPath, walPath],
                for: ObjectIdentifier(self),
                latency: 2
            ) { [weak self] _ in
                self?.scheduleRefresh()
            }
            isWatching = true
        } catch {
            log.error("Failed to start shortcut watcher: \(error)")
        }
    }

    public func stopWatching() {
        guard isWatching else { return }
        LowtechFSEvents.stopWatching(for: ObjectIdentifier(self))
        isWatching = false
    }

    private var isFetching = false
    private var isWatching = false
    private var lastFetch: Date?
    private var refreshTask: DispatchWorkItem?

    private func scheduleRefresh() {
        refreshTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.invalidateCache()
        }
        refreshTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
}

public let SHM = ShortcutsManager.shared

// MARK: - SwiftUI

/// Folder-grouped menu of all installed shortcuts.
/// Use inside a `Picker` (tag-based selection) or pass `onShortcutChosen` for a button-based flow.
public struct ShortcutChoiceMenu: View {
    public init(onShortcutChosen: ((Shortcut) -> Void)? = nil) {
        self.onShortcutChosen = onShortcutChosen
    }

    public var onShortcutChosen: ((Shortcut) -> Void)?

    public var body: some View {
        if shortcutsManager.hasFetched {
            let grouped = shortcutsManager.groupedByFolder
            if grouped.isEmpty {
                Text("No shortcuts found").disabled(true)
            } else if grouped.count == 1, let only = grouped.first {
                shortcutList(only.shortcuts)
            } else {
                ForEach(grouped, id: \.folder) { folder, shortcuts in
                    Section(folder ?? "Other") {
                        shortcutList(shortcuts)
                    }
                }
            }
        } else {
            Text("Loading...")
                .disabled(true)
                .onAppear { shortcutsManager.fetch() }
        }
    }

    @ObservedObject var shortcutsManager = SHM

    @ViewBuilder
    private func shortcutList(_ shortcuts: [Shortcut]) -> some View {
        if let onShortcutChosen {
            ForEach(shortcuts) { shortcut in
                Button(shortcut.name) { onShortcutChosen(shortcut) }
            }
        } else {
            ForEach(shortcuts) { shortcut in
                Text(shortcut.name).tag(shortcut as Shortcut?)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

/// Compound picker: a folder-grouped Menu (with folder submenus) plus an "open in Shortcuts" hammer button.
public struct ShortcutsPicker: View {
    public init(shortcut: Binding<Shortcut?>, placeholder: String = "Select shortcut") {
        _shortcut = shortcut
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack {
            Menu {
                if shortcutsManager.hasFetched {
                    let grouped = shortcutsManager.groupedByFolder
                    if grouped.isEmpty {
                        Text("No shortcuts found").disabled(true)
                    } else {
                        let ungrouped = grouped.first { $0.folder == nil }?.shortcuts ?? []
                        let folders = grouped.filter { $0.folder != nil }

                        ForEach(ungrouped) { s in
                            Button(s.name) { shortcut = s }
                        }
                        if !ungrouped.isEmpty, !folders.isEmpty {
                            Divider()
                        }
                        ForEach(folders, id: \.folder) { group in
                            Menu(group.folder ?? "") {
                                ForEach(group.shortcuts) { s in
                                    Button(s.name) { shortcut = s }
                                }
                            }
                        }
                    }
                } else {
                    Text("Loading...").disabled(true)
                }
            } label: {
                Text(shortcut?.name ?? placeholder)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button {
                if let url = shortcut?.url {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: shortcut == nil ? "hammer" : "hammer.fill")
            }
            .help("Open the shortcut in the Shortcuts app for editing")
            .disabled(shortcut == nil)
        }
        .onAppear { shortcutsManager.fetch() }
    }

    @ObservedObject var shortcutsManager = SHM
    @Binding var shortcut: Shortcut?

    var placeholder: String

}

/// Decorative Shortcuts app icon stand-in — used as a button adornment in shortcut pickers.
public struct ShortcutsIcon: View {
    public init(size: CGFloat = 20) { self.size = size }

    public var size: CGFloat

    public var body: some View {
        VStack(spacing: -size / 1.8) {
            RoundedRectangle(cornerRadius: size / 3, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hue: 0.02, saturation: 0.61, brightness: 0.89, opacity: 1.00), location: 0),
                    .init(color: Color(hue: 0.87, saturation: 0.51, brightness: 0.89, opacity: 0.9), location: 0.5),
                    .init(color: Color(hue: 0.87, saturation: 0.51, brightness: 0.89, opacity: 0.3), location: 0.9),
                ], startPoint: .leading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.7), radius: size / 4, y: 2)
                .rotationEffect(.degrees(-45))
                .scaleEffect(y: 0.85)
            RoundedRectangle(cornerRadius: size / 3, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hue: 0.59, saturation: 0.49, brightness: 0.48, opacity: 1.00), location: 0),
                    .init(color: Color(hue: 0.46, saturation: 0.46, brightness: 0.74, opacity: 0.9), location: 0.5),
                    .init(color: Color(hue: 0.61, saturation: 0.76, brightness: 0.94, opacity: 1.00), location: 0.9),
                ], startPoint: .top, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-45))
                .scaleEffect(y: 0.85)
                .zIndex(-1)
        }
    }
}
