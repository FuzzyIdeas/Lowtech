import Cocoa
import Foundation
import SwiftUI

// MARK: - OSDWindow

open class OSDWindow: NSWindow {
    // MARK: Lifecycle

    public convenience init(swiftuiView: some View, allSpaces: Bool = true, canScreenshot: Bool = true) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        level = NSWindow.Level(CGShieldingWindowLevel().i)
        collectionBehavior = [.stationary, .ignoresCycle, .fullScreenDisallowsTiling]
        if allSpaces {
            collectionBehavior.formUnion(.canJoinAllSpaces)
        } else {
            collectionBehavior.formUnion(.moveToActiveSpace)
        }
        if !canScreenshot {
            sharingType = .none
        }
        ignoresMouseEvents = true
        setAccessibilityRole(.popover)
        setAccessibilitySubrole(.unknown)

        backgroundColor = .clear
        contentView?.bg = .clear
        isOpaque = false
        hasShadow = false
        styleMask = [.fullSizeContentView]
        hidesOnDeactivate = false
    }

    // MARK: Open

    open func show(
        at point: NSPoint? = nil,
        closeAfter closeMilliseconds: Int = 3050,
        fadeAfter fadeMilliseconds: Int = 2000,
        offCenter: CGFloat? = nil,
        centerWindow: Bool = true
    ) {
        if let point = point {
            setFrameOrigin(point)
        } else if let screenFrame = (NSScreen.withMouse ?? NSScreen.main)?.visibleFrame {
            setFrameOrigin(screenFrame.origin)
            if centerWindow { center() }
            if offCenter != 0 {
                let yOff = screenFrame.height / (offCenter ?? 2.2)
                setFrame(frame.offsetBy(dx: 0, dy: -yOff), display: false)
            }
        }

        alphaValue = 1
        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()

        closer?.cancel()
        guard closeMilliseconds > 0 else { return }
        fader = mainAsyncAfter(ms: fadeMilliseconds) { [weak self] in
            guard let self, self.isVisible else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1
                self.animator().alphaValue = 0.01
            }

            self.closer = mainAsyncAfter(ms: closeMilliseconds) { [weak self] in
                self?.close()
            }
        }
    }

    // MARK: Public

    public func moveToScreen(_ screen: NSScreen? = nil) {
        guard let screenFrame = (screen ?? NSScreen.withMouse ?? NSScreen.main)?.visibleFrame else {
            return
        }
        setFrameOrigin(screenFrame.origin)
    }

    public func centerOnScreen(_: NSScreen? = nil) {
        if let screenFrame = (NSScreen.withMouse ?? NSScreen.main)?.visibleFrame {
            setFrameOrigin(screenFrame.origin)
        }
        center()
    }

    // MARK: Internal

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

    // MARK: Private

    private lazy var wc = NSWindowController(window: self)
}
