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

    open func show(at point: NSPoint? = nil) {
        if let point = point {
            setFrameOrigin(point)
        } else {
            center()
        }

        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    // MARK: Private

    private lazy var wc = NSWindowController(window: self)
}
