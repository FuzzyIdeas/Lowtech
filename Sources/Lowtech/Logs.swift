import Foundation
import os

#if DEBUG
    @inline(__always) public func debug(_ message: @autoclosure @escaping () -> String) {
        log.oslog.debug("\(message())")
    }

    @inline(__always) public func trace(_ message: @autoclosure @escaping () -> String) {
        log.oslog.trace("\(message())")
    }

    @inline(__always) public func err(_ message: @autoclosure @escaping () -> String) {
        log.oslog.critical("\(message())")
    }
#else
    @inline(__always) public func trace(_: @autoclosure () -> String) {}
    @inline(__always) public func debug(_: @autoclosure () -> String) {}
    @inline(__always) public func err(_: @autoclosure () -> String) {}
#endif

// MARK: - SwiftyLogger

public final class SwiftyLogger {
    @inline(__always) public class func verbose(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.trace("🫥 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.trace("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) public class func debug(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.debug("🌲 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.debug("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) public class func info(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.info("💠 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.info("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) public class func warning(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.warning("🦧 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.warning("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) public class func error(_ message: String, context: Any? = "") {
        #if DEBUG
            oslog.fault("👹 \(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #else
            oslog.fault("\(message, privacy: .public) \(String(describing: context ?? ""), privacy: .public)")
        #endif
    }

    @inline(__always) public class func traceCalls() {
        traceLog.trace("\(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")
    }

    static let oslog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.lowtechguys.Logger", category: "default")
    static let traceLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.lowtechguys.Logger", category: "trace")
}

public let log = SwiftyLogger.self
