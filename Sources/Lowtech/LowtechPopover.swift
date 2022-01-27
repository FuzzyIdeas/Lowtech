import Cocoa
import Defaults
import Foundation

// MARK: - LowtechPopover

open class LowtechPopover: NSPopover {
    // MARK: Lifecycle

    public init(_ statusBar: StatusBarController?) {
        super.init()
        self.statusBar = statusBar
        mockView = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: 2))
        mockView?.bg = .clear

        mockWindow = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 2, height: 2),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        mockWindow?.contentView = mockView
        mockWindow?.level = .statusBar
        mockWindow?.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
        mockWindow?.sharingType = .none
        mockWindow?.ignoresMouseEvents = true
        mockWindow?.setAccessibilityRole(.menuBarItem)
        mockWindow?.setAccessibilitySubrole(.unknown)

        mockWindow?.backgroundColor = .clear
        mockWindow?.isOpaque = false
        mockWindow?.hasShadow = false
        mockWindow?.hidesOnDeactivate = false
        mockWindowController = NSWindowController(window: mockWindow)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: Open

    override open func close() {
        super.close()
        mockWindow?.close()
    }

    open func show(menubarIconHidden: Bool? = nil) {
        if menubarIconHidden ?? Defaults[.hideMenubarIcon] {
            if let frame = NSScreen.main?.visibleFrame {
                let maxAllowedWindowX = (frame.width + frame.origin.x) - 400
                showAt(point: NSPoint(x: maxAllowedWindowX, y: frame.maxY - 30))
            } else {
                showAt()
            }
        } else if let button = statusBar?.statusItem.button {
            show(relativeTo: button.frame, of: button, preferredEdge: .minY)
        }
    }

    open func showAt(point: NSPoint? = nil, preferredEdge: NSRectEdge = .maxY) {
        guard let mockWindow = mockWindow, let mockWindowController = mockWindowController, let view = mockWindow.contentView else {
            return
        }

        if let point = point {
            mockWindow.setFrameOrigin(point)
        } else {
            mockWindow.center()
        }
        mockWindowController.showWindow(self)
        mockWindow.makeKeyAndOrderFront(self)
        mockWindow.orderFrontRegardless()
        show(relativeTo: view.bounds, of: view, preferredEdge: preferredEdge)
    }

    // MARK: Internal

    weak var statusBar: StatusBarController?

    // MARK: Private

    private var mockWindow: NSWindow?
    private var mockWindowController: NSWindowController?
    private var mockView: NSView?
}

public extension NSPoint {
    static func mouseLocation(centeredOn window: NSWindow? = nil) -> NSPoint {
        let loc = NSEvent.mouseLocation
        if let window = window {
            return loc.applying(.init(translationX: window.frame.width / -2, y: window.frame.height / -2))
        }
        return loc
    }
}
