import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

class PanelWindow: NSWindow {
    // MARK: Lifecycle

    convenience init(swiftuiView: AnyView) {
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

    // MARK: Internal

    func show(at point: NSPoint? = nil) {
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
