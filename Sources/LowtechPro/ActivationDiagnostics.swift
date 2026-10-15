import AppKit
import Darwin
import Foundation
import Lowtech
import os

private let logger = Logger(subsystem: lowtechLogSubsystem, category: "ActivationDiagnostics")

// MARK: - ActivationDiagnosis

/// What went wrong with a licence activation, worded for the alert that replaces Paddle's own.
public struct ActivationDiagnosis: Equatable {
    public let title: String
    public let message: String
    /// Hosts lines, failed connections and the Paddle error code, shown in small text under the message
    public let detail: String?
}

// MARK: - ActivationDiagnostics

/// Finds the real reason behind Paddle's "unable to activate": a hosts file or a network filter
/// keeping Paddle's servers out, or a licence refused for a reason Paddle words vaguely.
///
/// Kept free of the Paddle framework so it builds and can be tested on its own.
public enum ActivationDiagnostics {
    public enum Cause: Equatable {
        case expired
        case chargeback
        case refundedOrDisabled
        case otherMac
        case activationLimit
        case wrongLicence
        /// Paddle's generic -107, which covers a full licence as well as a blocked network
        case unableToActivate
    }

    public struct ProbeResult: Equatable {
        public let host: String
        public let reachable: Bool
        public let failure: String?
    }

    /// Domains Paddle's SDK talks to during activation and checkout
    public static let paddleDomains = [
        "paddle.com", "access.paddle.com", "checkout.paddle.com", "v3.paddleapi.com",
        "paddleapi.com", "vendors.paddle.com", "paddle.s3.amazonaws.com",
    ]
    public static let probeURLs = [
        URL(string: "https://v3.paddleapi.com")!,
        URL(string: "https://checkout.paddle.com")!,
    ]

    /// Maps a raw `NSError.code` from Paddle. The SDK reports negative codes, and passes the API's
    /// positive ones through unchanged, so both are listed.
    public static func cause(forPaddleErrorCode code: Int) -> Cause? {
        switch code {
        case -123, 140: .expired
        case -131, 146: .chargeback
        case 105: .refundedOrDisabled
        case -127, 144: .otherMac
        case -122, -126, 104: .activationLimit
        case -124, 100, 138: .wrongLicence
        case -107: .unableToActivate
        default: nil
        }
    }

    /// Lines of the hosts file that send a Paddle domain (or a subdomain of one) to this Mac or nowhere
    public static func blockingHostsLines(hostsFile: String = "/etc/hosts") -> [String] {
        guard let contents = try? String(contentsOfFile: hostsFile, encoding: .utf8) else { return [] }
        return blockingHostsLines(contents: contents)
    }

    public static func blockingHostsLines(contents: String) -> [String] {
        let sinkholes: Set<String> = ["0.0.0.0", "127.0.0.1", "::1", "::"]
        let domains = Set(paddleDomains)

        return contents.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let fields = line.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
            guard fields.count >= 2, sinkholes.contains(fields[0]) else { return nil }

            let blocksPaddle = fields.dropFirst().contains { host in
                domains.contains(host) || host.hasSuffix(".paddle.com") || host.hasSuffix(".paddleapi.com")
            }
            return blocksPaddle ? line : nil
        }
    }

    /// Names of running network filters that could block the app's connections
    public static func runningNetworkFilters() -> [String] {
        let filters: [(name: String, bundlePrefixes: [String], processNames: [String])] = [
            ("LuLu", ["com.objective-see.lulu"], ["lulu"]),
            ("Little Snitch", ["at.obdev.littlesnitch"], ["little snitch", "littlesnitch"]),
            ("Radio Silence", ["com.radiosilenceapp"], ["radio silence", "radiosilence"]),
            ("Murus", [], ["murus"]),
            ("Vallum", [], ["vallum"]),
        ]

        var names = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            names.formUnion([
                app.bundleIdentifier, app.localizedName, app.executableURL?.lastPathComponent,
            ].compactMap { $0?.lowercased() })
        }
        names.formUnion(runningProcessNames())

        return filters.filter { filter in
            names.contains { name in
                filter.bundlePrefixes.contains { name.hasPrefix($0) } || filter.processNames.contains { name.hasPrefix($0) }
            }
        }.map(\.name)
    }

    /// Connects to Paddle's servers, every request in parallel and bounded by `timeout`.
    /// Any HTTP response counts as reachable, even a 4xx.
    public static func probePaddle(timeout: TimeInterval = 5) async -> [ProbeResult] {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        return await withTaskGroup(of: ProbeResult.self) { group in
            for url in probeURLs {
                group.addTask {
                    let host = url.host ?? url.absoluteString
                    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
                    request.httpMethod = "HEAD"
                    do {
                        let (_, response) = try await session.data(for: request)
                        return ProbeResult(host: host, reachable: response is HTTPURLResponse, failure: nil)
                    } catch {
                        return ProbeResult(host: host, reachable: false, failure: describe(error, timeout: timeout))
                    }
                }
            }
            var results: [ProbeResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { a, b in
                (probeURLs.firstIndex { $0.host == a.host } ?? 0) < (probeURLs.firstIndex { $0.host == b.host } ?? 0)
            }
        }
    }

    /// Composes the alert for a failed activation. Returns nil when nothing better than Paddle's own
    /// text was found. Touches the network, the disk and the process list, so keep it off the main thread.
    public static func diagnose(paddleErrorCode code: Int?, appName: String) async -> ActivationDiagnosis? {
        let cause = code.flatMap { cause(forPaddleErrorCode: $0) }
        let codeLine = code.map { "Paddle error \($0)" }

        func diagnosis(_ title: String, _ message: String, _ lines: [String] = []) -> ActivationDiagnosis {
            let detail = (lines + [codeLine].compactMap { $0 }).joined(separator: "\n")
            return ActivationDiagnosis(title: title, message: message, detail: detail.isEmpty ? nil : detail)
        }

        // Paddle's servers answered with a reason, so the network is fine
        switch cause {
        case .expired:
            return diagnosis("This licence has expired", "Renew it or buy a new licence, then activate again.")
        case .chargeback:
            return diagnosis("This licence was disabled after a chargeback", "Contact support if you think this is a mistake.")
        case .refundedOrDisabled:
            return diagnosis("This licence isn't active", "It was refunded or disabled. Contact support if you think this is a mistake.")
        // The app already tried freeing the oldest activation for these, so there's nothing to deactivate by hand
        case .otherMac, .activationLimit:
            return diagnosis(couldNotActivateTitle, couldNotActivateMessage)
        case .wrongLicence:
            return diagnosis("This licence code doesn't match \(appName)", "Check that you copied the code from the right receipt, then try again.")
        case .unableToActivate, nil:
            break
        }

        let hostsLines = blockingHostsLines()
        if !hostsLines.isEmpty {
            logger.error("Paddle is blocked in /etc/hosts: \(hostsLines.joined(separator: "; "))")
            return diagnosis(
                "Paddle is blocked in /etc/hosts",
                "Your hosts file sends Paddle's servers to this Mac, so \(appName) can't reach them to activate the licence. Remove the lines below from /etc/hosts, then try again.",
                hostsLines
            )
        }

        let failed = await probePaddle().filter { !$0.reachable }
        if !failed.isEmpty {
            let failures = failed.map { "\($0.host): \($0.failure ?? "no response")" }
            logger.error("Paddle unreachable: \(failures.joined(separator: "; "))")

            let filters = runningNetworkFilters()
            guard filters.isEmpty else {
                let filterNames = joinedNames(filters)
                return diagnosis(
                    "Paddle's servers can't be reached",
                    "\(filterNames) \(filters.count == 1 ? "is" : "are") running and may be blocking \(appName). Allow \(appName) to connect to paddle.com and paddleapi.com in \(filterNames), then try again.",
                    failures
                )
            }
            return diagnosis("Paddle's servers can't be reached", "Check your internet connection, VPN or firewall, then try again.", failures)
        }

        if cause == .unableToActivate {
            return diagnosis(couldNotActivateTitle, couldNotActivateMessage)
        }
        return nil
    }

    static let couldNotActivateTitle = "Paddle couldn't activate this licence"
    static let couldNotActivateMessage = "Try again, and contact support if it keeps failing."

    static func describe(_ error: Error, timeout: TimeInterval) -> String {
        guard let urlError = error as? URLError else { return error.localizedDescription }
        switch urlError.code {
        case .timedOut: return "timed out after \(String(format: "%.1f", timeout)) s"
        case .cannotConnectToHost: return "connection refused"
        case .cannotFindHost, .dnsLookupFailed: return "DNS lookup failed"
        case .notConnectedToInternet: return "no internet connection"
        case .networkConnectionLost: return "connection lost"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot, .clientCertificateRejected:
            return "TLS failed"
        default: return urlError.localizedDescription
        }
    }

    static func joinedNames(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// Lowercased names of every process, to catch filter daemons that aren't NSRunningApplications
    static func runningProcessNames() -> Set<String> {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }

        var names = Set<String>()
        var buffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2 + 1)
        for pid in pids.prefix(Int(filled)) where pid > 0 {
            guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
            names.insert(String(cString: buffer).lowercased())
        }
        return names
    }
}
