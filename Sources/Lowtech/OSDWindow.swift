import Cocoa
import Foundation
import SwiftUI

// MARK: - OSDWindow

open class OSDWindow: NSWindow {
    // MARK: Lifecycle

    public convenience init(swiftuiView: AnyView) {
        self.init(contentViewController: NSHostingController(rootView: swiftuiView))

        level = NSWindow.Level(CGShieldingWindowLevel().i)
        collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenDisallowsTiling]
        sharingType = .none
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

    open func show(at point: NSPoint? = nil, closeAfter closeMilliseconds: Int = 3050, fadeAfter fadeMilliseconds: Int = 2000) {
        if let point = point {
            setFrameOrigin(point)
        } else {
            center()
            let yOff = ((NSScreen.withMouse ?? NSScreen.main)?.visibleFrame.height ?? 500) / 2.2
            setFrame(frame.offsetBy(dx: 0, dy: -yOff), display: false)
        }

        contentView?.alphaValue = 1
        wc.showWindow(nil)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()

        closer?.cancel()
        guard closeMilliseconds > 0 else { return }
        fader = mainAsyncAfter(ms: fadeMilliseconds) { [weak self] in
            guard let s = self, s.isVisible else { return }
            s.contentView?.transition(1)
            s.contentView?.alphaValue = 0.01

            s.closer = mainAsyncAfter(ms: closeMilliseconds) { [weak self] in
                self?.close()
            }
        }
    }

    // MARK: Public

    public var closer: DispatchWorkItem? {
        didSet {
            guard let oldCloser = oldValue else {
                return
            }
            oldCloser.cancel()
        }
    }

    public var fader: DispatchWorkItem? {
        didSet {
            guard let oldCloser = oldValue else {
                return
            }
            oldCloser.cancel()
        }
    }

    // MARK: Private

    private lazy var wc = NSWindowController(window: self)
}
