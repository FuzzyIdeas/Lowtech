import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

open class PanelWindow: NSWindow {
    // MARK: Lifecycle

    public convenience init(swiftuiView: AnyView) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        level = .floating
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    // MARK: Open

    override open var canBecomeKey: Bool { true }

    open func show(at point: NSPoint? = nil, animate: Bool = false, activate: Bool = true) {
        if let point = point {
            if animate {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = .easeOut
                    ctx.allowsImplicitAnimation = true
                    setFrame(NSRect(origin: point, size: frame.size), display: true, animate: true)
                }
            } else {
                setFrameOrigin(point)
            }
        } else {
            center()
        }

        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Public

    public func forceClose() {
        wc.close()
        wc.window = nil
        close()
    }

    // MARK: Private

    private lazy var wc = NSWindowController(window: self)
}
