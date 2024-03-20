import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

// MARK: - OSDWindow

open class OSDWindow: LowtechWindow {
    public convenience init(
        swiftuiView: AnyView,
        releaseWhenClosed: Bool = true,
        level: NSWindow.Level = NSWindow.Level(CGShieldingWindowLevel().i),
        allSpaces: Bool = true,
        canScreenshot: Bool = true,
        screen: NSScreen? = nil,
        corner: ScreenCorner? = nil,
        allowsMouse: Bool = false
    ) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        screenPlacement = screen
        screenCorner = corner

        self.level = level
        collectionBehavior = [.stationary, .ignoresCycle, .fullScreenDisallowsTiling]
        if allSpaces {
            collectionBehavior.formUnion(.canJoinAllSpaces)
        } else {
            collectionBehavior.formUnion(.moveToActiveSpace)
        }
        if !canScreenshot {
            sharingType = .none
        }
        ignoresMouseEvents = !allowsMouse
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
        isReleasedWhenClosed = releaseWhenClosed
        delegate = self
    }

    open func show(
        at point: NSPoint? = nil,
        closeAfter closeMilliseconds: Int = 3050,
        fadeAfter fadeMilliseconds: Int = 2000,
        offCenter: CGFloat? = nil,
        verticalOffset: CGFloat? = nil,
        centerWindow: Bool = true,
        corner: ScreenCorner? = nil,
        margin: CGFloat? = nil,
        screen: NSScreen? = nil,
        animate: Bool = false
    ) {
        if let corner {
            moveToScreen(screen, corner: corner, margin: margin, animate: animate)
        } else if let point {
            withAnim(animate: animate) { w in w.setFrameOrigin(point) }
        } else if let screenFrame = (screen ?? NSScreen.withMouse ?? NSScreen.main)?.visibleFrame {
            withAnim(animate: animate) { w in
                w.setFrameOrigin(screenFrame.origin)
                if centerWindow { w.center() }
                if let verticalOffset {
                    setFrameOrigin(CGPoint(
                        x: (screenFrame.width / 2 - frame.size.width / 2) + screenFrame.origin.x,
                        y: screenFrame.origin.y + verticalOffset
                    ))
                } else if offCenter != 0 {
                    let yOff = screenFrame.height / (offCenter ?? 2.2)
                    w.setFrame(frame.offsetBy(dx: 0, dy: -yOff), display: false)
                }
            }
        }

        alphaValue = 1
        wc.showWindow(nil)
        if canBecomeKey {
            makeKeyAndOrderFront(nil)
        }
        orderFrontRegardless()

        closer?.cancel()
        guard closeMilliseconds > 0 else { return }
        fader = mainAsyncAfter(ms: fadeMilliseconds) { [weak self] in
            guard let self, isVisible else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1
                self.animator().alphaValue = 0.01
            }

            closer = mainAsyncAfter(ms: closeMilliseconds) { [weak self] in
                self?.close()
            }
        }
    }

    public func hide() {
        fader = nil
        closer = nil

        if let v = contentView?.superview {
            v.alphaValue = 0.0
        }
        close()
        windowController?.close()
    }

    var closer: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }

    var fader: DispatchWorkItem? {
        didSet {
            oldValue?.cancel()
        }
    }
}

// MARK: - LowtechWindow

open class LowtechWindow: NSWindow, NSWindowDelegate {
    open var onMouseUp: ((NSEvent) -> Void)?
    open var onMouseDown: ((NSEvent) -> Void)?
    open var onMouseDrag: ((NSEvent) -> Void)?

    override open func mouseDragged(with event: NSEvent) {
        guard !ignoresMouseEvents, let onMouseDrag else { return }
        onMouseDrag(event)
    }

    override open func mouseDown(with event: NSEvent) {
        guard !ignoresMouseEvents, let onMouseDown else { return }
        onMouseDown(event)
    }

    override open func mouseUp(with event: NSEvent) {
        guard !ignoresMouseEvents, let onMouseUp else { return }
        onMouseUp(event)
    }

    public var closed = true
    public var animateOnResize = false
    @Published public var screenPlacement: NSScreen?

    public var screenCorner: ScreenCorner?
    public var margin: CGFloat = 0

    public lazy var wc = NSWindowController(window: self)

    public func windowDidBecomeKey(_ notification: Notification) {
        closed = false
    }

    public func windowDidBecomeMain(_ notification: Notification) {
        closed = false
    }

    public func windowWillClose(_ notification: Notification) {
        closed = true
    }

    public func windowDidResize(_ notification: Notification) {
        guard let screenCorner, let screenPlacement else { return }
        moveToScreen(screenPlacement, corner: screenCorner, animate: animateOnResize)
    }

    public func resizeToScreenHeight(_ screen: NSScreen? = nil, animate: Bool = false) {
        guard let screenFrame = (screen ?? NSScreen.withMouse ?? NSScreen.main)?.visibleFrame else {
            return
        }
        withAnim(animate: animate) { w in
            w.setContentSize(NSSize(width: frame.width, height: screenFrame.height))
        }
    }

    public func centerOnScreen(_ screen: NSScreen? = nil, animate: Bool = false) {
        withAnim(animate: animate) { w in
            if let screenFrame = (screen ?? NSScreen.withMouse ?? NSScreen.main)?.visibleFrame {
                w.setFrameOrigin(screenFrame.origin)
            }
            w.center()
        }
    }

    public func moveToScreen(_ screen: NSScreen? = nil, corner: ScreenCorner? = nil, margin: CGFloat? = nil, animate: Bool = false) {
        guard let screenFrame = (screen ?? NSScreen.withMouse ?? NSScreen.main)?.visibleFrame else {
            return
        }

        if let margin {
            self.margin = margin
        }
        if let screen {
            screenPlacement = screen
        }

        withAnim(animate: animate) { w in
            guard let corner else {
                w.setFrameOrigin(screenFrame.origin)
                return
            }

            screenCorner = corner
            let scrO = screenFrame.origin
            let scrF = screenFrame

            switch corner {
            case .bottomLeft:
                w.setFrameOrigin(scrO.applying(.init(translationX: self.margin, y: self.margin)))
            case .bottomRight:
                w.setFrameOrigin(
                    NSPoint(
                        x: (scrO.x + scrF.width) - frame.width,
                        y: scrO.y
                    )
                    .applying(.init(translationX: -self.margin, y: self.margin))
                )
            case .topLeft:
                w.setFrameOrigin(
                    NSPoint(
                        x: scrO.x,
                        y: frame.height > scrF.height ? scrO.y : (scrO.y + scrF.height) - frame.height
                    )
                    .applying(.init(translationX: self.margin, y: -self.margin))
                )
            case .topRight:
                w.setFrameOrigin(
                    NSPoint(
                        x: (scrO.x + scrF.width) - frame.width,
                        y: frame.height > scrF.height ? scrO.y : (scrO.y + scrF.height) - frame.height
                    )
                    .applying(.init(translationX: -self.margin, y: -self.margin))
                )
            case .top:
                w.setFrameOrigin(
                    NSPoint(
                        x: scrO.x + (scrF.width - frame.width) / 2,
                        y: (scrO.y + scrF.height) - frame.height
                    )
                    .applying(.init(translationX: 0, y: -self.margin))
                )
            case .bottom:
                w.setFrameOrigin(
                    NSPoint(
                        x: scrO.x + (scrF.width - frame.width) / 2,
                        y: scrO.y
                    )
                    .applying(.init(translationX: 0, y: self.margin))
                )
            case .left:
                w.setFrameOrigin(
                    NSPoint(
                        x: scrO.x,
                        y: frame.height > scrF.height ? scrO.y : scrO.y + (scrF.height - frame.height) / 2
                    )
                    .applying(.init(translationX: self.margin, y: 0))
                )
            case .right:
                w.setFrameOrigin(
                    NSPoint(
                        x: (scrO.x + scrF.width) - frame.width,
                        y: frame.height > scrF.height ? scrO.y : scrO.y + (scrF.height - frame.height) / 2
                    )
                    .applying(.init(translationX: -self.margin, y: 0))
                )
            case .center:
                w.setFrameOrigin(NSPoint(
                    x: scrO.x + (scrF.width - frame.width) / 2,
                    y: frame.height > scrF.height ? scrO.y : scrO.y + (scrF.height - frame.height) / 2
                ))
//                w.center()
            }
        }
    }

    public func forceClose() {
        wc.close()
        wc.window = nil
        close()
    }

    public func withAnim(_ easing: CAMediaTimingFunction = .easeOutExpo, duration: Double = 0.3, animate: Bool = true, onEnd: (() -> Void)? = nil, _ action: (LowtechWindow) -> Void) {
        guard animate else {
            action(self)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.timingFunction = easing
            ctx.allowsImplicitAnimation = true
            ctx.duration = duration
            action(animator())
        }, completionHandler: onEnd)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isReleasedWhenClosed else { return true }
        windowController?.window = nil
        windowController = nil
        return true
    }

    @Atomic var inAnim = false
}

// MARK: - ScreenCorner

public enum ScreenCorner: Int, Codable, Defaults.Serializable {
    case bottomLeft
    case bottomRight
    case topLeft
    case topRight

    case top
    case bottom
    case left
    case right

    case center
}
