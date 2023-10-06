import Cocoa

// MARK: - GlobalEventMonitor

@MainActor
open class GlobalEventMonitor {
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        Task.init { await MainActor.run { stop() } }
    }

    public func start() {
        #if DEBUG
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
                if let event {
                    print("[GLOBAL] Handling mask \(self.mask) on event: \(event)")
                }
                self.handler(event)
            }) as! NSObject
        #else
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
        #endif
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
}

// MARK: - LocalEventMonitor

@MainActor
open class LocalEventMonitor {
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        Task.init { await MainActor.run { stop() } }
    }

    public func start() {
        #if DEBUG
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                print("[LOCAL] Handling mask \(self.mask) on event: \(event)")
                return self.handler(event)
            }) as! NSObject
        #else
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler) as! NSObject
        #endif
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> NSEvent?
}
