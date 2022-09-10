import Cocoa

// MARK: - GlobalEventMonitor

@MainActor
open class GlobalEventMonitor {
    // MARK: Lifecycle

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        Task.init { await MainActor.run { stop() } }
    }

    // MARK: Public

    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }

    // MARK: Private

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
}

// MARK: - LocalEventMonitor

@MainActor
open class LocalEventMonitor {
    // MARK: Lifecycle

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        Task.init { await MainActor.run { stop() } }
    }

    // MARK: Public

    public func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }

    // MARK: Private

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> NSEvent?
}
