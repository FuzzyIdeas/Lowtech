import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

open class PanelWindow: LowtechWindow {
    public convenience init(swiftuiView: AnyView, screen: NSScreen? = nil, corner: ScreenCorner? = nil) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        screenPlacement = screen
        screenCorner = corner

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

    override open var canBecomeKey: Bool { true }

    open func show(at point: NSPoint? = nil, animate: Bool = false, activate: Bool = true, corner: ScreenCorner? = nil, margin: CGFloat? = nil, marginHorizontal: CGFloat? = nil, screen: NSScreen? = nil) {
        if let corner {
            moveToScreen(screen, corner: corner, margin: margin, animate: animate)
        } else if let point {
            withAnim(animate: animate) { w in w.setFrameOrigin(point) }
        } else {
            withAnim(animate: animate) { w in w.center() }
        }

        wc.showWindow(nil)
        if canBecomeKey {
            makeKeyAndOrderFront(nil)
        }
        orderFrontRegardless()
        if activate {
            focus()
        }
    }
}
