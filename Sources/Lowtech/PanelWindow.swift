import Cocoa
import Foundation
import SwiftUI

// MARK: - PanelWindow

open class PanelWindow: LowtechWindow {
    public convenience init(swiftuiView: AnyView, screen: NSScreen? = nil, corner: ScreenCorner? = nil, styleMask: NSWindow.StyleMask? = nil, collectionBehavior: NSWindow.CollectionBehavior? = nil) {
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
        self.styleMask = styleMask ?? [.fullSizeContentView]
        if let collectionBehavior {
            self.collectionBehavior = collectionBehavior
        }
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
    }

    override open var acceptsFirstResponder: Bool {
        true
    }

    override open var canBecomeKey: Bool {
        true
    }

    open func show(at point: NSPoint? = nil, animate: Bool = false, activate: Bool = true, corner: ScreenCorner? = nil, margin: CGFloat? = nil, marginHorizontal: CGFloat? = nil, screen: NSScreen? = nil) {
        if let corner {
            moveToScreen(screen, corner: corner, margin: margin, animate: animate)
        } else if let point {
            let onscreen = Self.clampOnscreen(origin: point, size: frame.size)
            withAnim(animate: animate) { w in w.setFrame(NSRect(origin: onscreen, size: frame.size), display: true) }
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

    /// Keep a window of `size` positioned at bottom-left `origin` (global Cocoa
    /// coordinates) fully within the visible frame of whichever screen it lands
    /// on. Without this, showing the window at the mouse location near a screen
    /// edge (e.g. the menubar-icon-hidden popover) would push most of it
    /// offscreen.
    static func clampOnscreen(origin: NSPoint, size: NSSize) -> NSPoint {
        let rect = NSRect(origin: origin, size: size)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let screen = NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
            ?? NSScreen.screens.max { intersectionArea($0.frame, rect) < intersectionArea($1.frame, rect) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }

        let x = size.width <= visible.width ? min(max(origin.x, visible.minX), visible.maxX - size.width) : visible.minX
        let y = size.height <= visible.height ? min(max(origin.y, visible.minY), visible.maxY - size.height) : visible.minY
        return NSPoint(x: x, y: y)
    }

    private static func intersectionArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
