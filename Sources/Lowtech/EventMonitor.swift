import Cocoa

// MARK: - GlobalEventMonitor

#if DEBUG
    var logGlobalEvents = false
#endif

// MARK: - GlobalEventMonitor

@MainActor
open class GlobalEventMonitor {
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        // Inline removeMonitor instead of `mainActor { self.stop() }` so we
        // don't capture self in an async Task while self is mid-deinit, which
        // tripped the Swift runtime ("deallocated with non-zero retain count").
        // NSEvent.removeMonitor(_:) is safe to call from any thread.
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    public func start() {
        #if DEBUG
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
                if event.type == .keyDown || event.type == .flagsChanged {
                    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.control, .option, .shift] {
                        logGlobalEvents = true
                    } else if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.control, .command, .shift] {
                        logGlobalEvents = false
                    }
                }
                if logGlobalEvents {
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
    private let handler: (NSEvent) -> Void
}

// MARK: - LocalEventMonitor

@MainActor
open class LocalEventMonitor {
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        // Inline removeMonitor instead of `mainActor { self.stop() }` so we
        // don't capture self in an async Task while self is mid-deinit, which
        // tripped the Swift runtime ("deallocated with non-zero retain count").
        // NSEvent.removeMonitor(_:) is safe to call from any thread.
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
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
