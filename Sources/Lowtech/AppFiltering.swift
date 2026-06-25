import AppKit
import Foundation
import System

// MARK: - Path-based app filtering

/// Paths that indicate non-user-facing app components (frameworks, XPC services, nested bundles)
public func matchesAppExcludePath(_ path: String) -> Bool {
    path.contains("/Library/")
        || path.contains("/Frameworks/")
        || path.contains("/PrivateFrameworks/")
        || path.contains(".framework")
        || path.contains(".xpc")
        || path.contains("BTTRelaunch")
        || (path.contains("/Applications/") && path.contains(".app/Contents"))
}

/// Known exceptions to exclude paths (legitimate apps in unusual locations)
public func matchesAppIncludePath(_ path: String) -> Bool {
    path.contains("/System/Library/CoreServices/Finder.app")
        || path.contains("/Users/Shared/Riot")
        || path.contains(".AppBundle")
        || path.contains("/Library/Caches/JetBrains")
        || path.contains("/Library/Application Support/JetBrains/Toolbox")
        || path.contains("/Applications/Chrome Apps.localized")
        || (path.hasSuffix(".app") && path.contains("/Applications/Xcode") && {
            guard let r = path.range(of: ".app/Contents/") else { return false }
            return path[r.upperBound...].contains("Applications/")
        }())
        || (path.contains("/Applications/Burp") && path.contains(".app/Contents"))
}

/// Whether a path points to a user-relevant app (not a framework, XPC service, etc.)
public func isAppPathRelevant(_ path: String) -> Bool {
    !matchesAppExcludePath(path) || matchesAppIncludePath(path)
}

@MainActor public var appPathRelevanceCache = [String: Bool]()

/// Cached version of `isAppPathRelevant` for hot paths
@MainActor public func isAppPathRelevantCached(_ path: String) -> Bool {
    if let cached = appPathRelevanceCache[path] { return cached }
    let result = isAppPathRelevant(path)
    appPathRelevanceCache[path] = result
    return result
}

// MARK: - Bundle helpers

public extension Bundle {
    /// The bundle's main executable, resolved **without** `executableURL`.
    ///
    /// `Bundle.executableURL` / `.executablePath` funnel through CoreFoundation's
    /// `_CFBundleCopyExecutableURLInDirectory2`, which calls `__builtin_trap()` (a
    /// fatal `EXC_BREAKPOINT`) when a bundle's `CFBundleExecutable` value can't be
    /// turned into a URL (empty or malformed). Some third-party apps ship such
    /// bundles, so resolve the executable from the Info.plist + the conventional
    /// `Contents/MacOS` layout instead, which can only ever return nil.
    var executable: FilePath? {
        guard let name = infoDictionary?["CFBundleExecutable"] as? String, !name.isEmpty else { return nil }
        return bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(name).filePath
    }
}

// MARK: - FilePath helpers

public extension FilePath {
    var fileReferenceURL: NSURL? {
        (url as NSURL).perform(#selector(NSURL.fileReferenceURL))?.takeUnretainedValue() as? NSURL
    }
}

// MARK: - NSRunningApplication filtering

public extension NSRunningApplication {
    /// Whether the running executable matches the bundle's executable (detects replaced binaries)
    var binaryIsValid: Bool {
        binaryValidCache.fetch(key: identifier, create: { [self] _ in
            guard let bundleExe = bundle?.executable?.fileReferenceURL,
                  let exePath = executableURL?.path,
                  let exe = exePath.filePath?.fileReferenceURL
            else { return true }
            return bundleExe == exe
        })
    }

    /// System processes that don't support AX observers/notifications
    static let systemBundleIDsWithoutAX: Set<String> = [
        "com.apple.dock",
        "com.apple.universalcontrol",
        "com.apple.WindowManager",
    ]

    /// Whether this app could have user-visible windows.
    ///
    /// Excludes background-only processes, XPC services, app extensions,
    /// known system processes without AX support, and renderer helpers.
    /// Does NOT filter by `isRegular`, so menu bar / accessory apps are included.
    var isUserFacingApp: Bool {
        guard let identifier = bundleIdentifier,
              identifier != Bundle.main.bundleIdentifier,
              let bundleURL,
              name != nil
        else { return false }

        if activationPolicy == .prohibited { return false }

        let ext = bundleURL.pathExtension
        if ext == "xpc" || ext == "appex" || ext == "bundle" { return false }

        if Self.systemBundleIDsWithoutAX.contains(identifier) { return false }
        if bundle?.name.contains("(Renderer)") == true { return false }

        let path = bundleURL.path
        if activationPolicy == .accessory {
            // System agents under /System/Library/ are never user-facing apps
            if path.hasPrefix("/System/Library/") { return false }

            // Nested helpers inside another .app bundle (e.g. Discord Helper, Claude Helper)
            if path.contains(".app/Contents/") { return false }
        }

        return true
    }
}

// MARK: - NSWorkspace convenience

public extension NSWorkspace {
    /// Running apps filtered to user-facing ones (excludes background services, XPC, app extensions, etc.)
    var relevantRunningApps: [NSRunningApplication] {
        runningApplications.filter(\.isUserFacingApp)
    }
}
