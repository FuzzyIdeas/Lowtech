import Foundation
import os

public let lowtechLogSubsystem = Bundle.main.bundleIdentifier ?? "com.lowtechguys.Logger"

// MARK: - SwiftyLogger

/// The logging layer the older apps (Grila, Gamma Dimmer, Startup Folder) are written against.
///
/// Newer code makes its own `Logger(subsystem: lowtechLogSubsystem, category:)` per file, which
/// is better: the category tells you where a line came from. This stays because dropping it left
/// `err("...")` resolving to Darwin's `err(3)` in those apps, which fails to compile with a
/// message that says nothing about the real cause.
public final class SwiftyLogger {
    @inline(__always) @inlinable public class func verbose(_ message: String, context: Any? = "") {
        oslog.trace("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
    }

    @inline(__always) @inlinable public class func debug(_ message: String, context: Any? = "") {
        oslog.debug("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
    }

    @inline(__always) @inlinable public class func info(_ message: String, context: Any? = "") {
        oslog.info("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
    }

    @inline(__always) @inlinable public class func warning(_ message: String, context: Any? = "") {
        oslog.warning("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
    }

    @inline(__always) @inlinable public class func error(_ message: String, context: Any? = "") {
        oslog.fault("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
    }

    @inline(__always) @inlinable public class func traceCalls() {
        traceLog.trace("\(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")
    }

    @usableFromInline static let oslog = Logger(subsystem: lowtechLogSubsystem, category: "default")
    @usableFromInline static let traceLog = Logger(subsystem: lowtechLogSubsystem, category: "trace")
}

public let log = SwiftyLogger.self

#if DEBUG
    @inline(__always) @inlinable public func debug(_ message: @autoclosure @escaping () -> String) {
        SwiftyLogger.oslog.debug("\(message())")
    }

    @inline(__always) @inlinable public func trace(_ message: @autoclosure @escaping () -> String) {
        SwiftyLogger.oslog.trace("\(message())")
    }

    @inline(__always) @inlinable public func err(_ message: @autoclosure @escaping () -> String) {
        SwiftyLogger.oslog.critical("\(message())")
    }
#else
    @inline(__always) @inlinable public func trace(_: @autoclosure () -> String) {}
    @inline(__always) @inlinable public func debug(_: @autoclosure () -> String) {}
    @inline(__always) @inlinable public func err(_: @autoclosure () -> String) {}
#endif
