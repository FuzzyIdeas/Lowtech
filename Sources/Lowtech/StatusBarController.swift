import AppKit
import Combine
import Defaults
import SwiftUI

// MARK: - StatusBarController

open class StatusBarController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    // MARK: Lifecycle

    public init(_ view: NSHostingView<AnyView>, image: String = "MenubarIcon") {
        self.view = view

        popover.contentViewController = MainViewController()
        popover.contentViewController!.view = view
        popover.animates = false

        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(named: image)
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true

            statusBarButton.action = #selector(togglePopover(sender:))
            statusBarButton.target = self
        }

        if Defaults[.hideMenubarIcon], let statusBarButton = statusItem.button {
            statusBarButton.image = nil
            statusItem.isVisible = false
        }

        Defaults.publisher(.hideMenubarIcon).removeDuplicates().filter { $0.oldValue != $0.newValue }.sink { [self] hidden in
            let wasHidingMenubarIcon = hidden.oldValue
            let showingMenubarIcon = !hidden.newValue
            let hidingMenubarIcon = hidden.newValue

            let windowLocation = wasHidingMenubarIcon ? window.frame.origin : popoverWindow?.frame.origin

            hidePopover(self)
            statusItem.isVisible = showingMenubarIcon
            statusItem.button?.image = hidingMenubarIcon ? nil : NSImage(named: image)

            guard popoverShownAtLeastOnce else { return }
            mainAsyncAfter(ms: 10) {
                self.showPopover(self, at: windowLocation)
            }
        }.store(in: &observers)

        eventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
        popover.delegate = self

        NSApp.publisher(for: \.mainMenu).sink { _ in self.fixMenu() }
            .store(in: &observers)
    }

    // MARK: Open

    open func windowWillClose(_: Notification) {
        debug("windowWillClose")
        if !Defaults[.popoverClosed] {
            Defaults[.popoverClosed] = true
        }
    }

    open func popoverDidClose(_: Notification) {
        debug("popoverDidClose")
        let positioningView = statusItem.button?.subviews.first {
            $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        }
        positioningView?.removeFromSuperview()
        if !Defaults[.popoverClosed] {
            Defaults[.popoverClosed] = true
        }
    }

    open func popoverWillShow(_: Notification) {
        debug("popoverWillShow")
        if Defaults[.popoverClosed] {
            Defaults[.popoverClosed] = false
        }
        popoverShownAtLeastOnce = true
    }

    // MARK: Public

    public var popover = NSPopover()
    public var view: NSHostingView<AnyView>

    public lazy var window: PanelWindow = {
        let w = PanelWindow(swiftuiView: view.rootView)
        w.delegate = self
        return w
    }()

    public var observers: Set<AnyCancellable> = []
    public var statusItem: NSStatusItem
    @Atomic public var popoverShownAtLeastOnce = false
    @Atomic public var shouldLeavePopoverOpen = false

    public var popoverWindow: NSWindow? {
        popover.contentViewController?.view.window
    }

    @objc public func togglePopover(sender: AnyObject) {
        tryc += 1
        if tryc <= 3 {
            mainAsyncAfter(ms: 100) {
                self.togglePopover(sender: LowtechAppDelegate.instance, at: nil)
            }
        } else {
            togglePopover(sender: LowtechAppDelegate.instance, at: nil)
        }
    }

    public func togglePopover(sender: AnyObject, at point: NSPoint? = nil) {
        if popover.isShown || window.isVisible {
            hidePopover(sender)
        } else {
            showPopover(sender, at: point)
        }
    }

    public func showPopoverIfNotVisible(at point: NSPoint? = nil) {
        guard !window.isVisible, !(popoverWindow?.isVisible ?? false) else { return }
        showPopover(self, at: point)
    }

    public func fixMenu() {
        let menu = NSMenu(title: "Edit")

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(withTitle: "Close Window", action: #selector(StatusBarController.hidePopover(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")

        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Edit"
        editMenuItem.submenu = menu
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu()
        }
        NSApp.mainMenu?.items = [editMenuItem]
    }

    public func refresh() {
        guard popover.isShown, let positioningView, let popoverWindow else { return }

        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .maxY)
        popoverWindow.setFrame(popoverWindow.frame.offsetBy(dx: 0, dy: 12), display: false)
        popoverWindow.makeKeyAndOrderFront(LowtechAppDelegate.instance)
    }

    public func showPopover(_ sender: AnyObject, at point: NSPoint? = nil, center: Bool = false) {
        guard statusItem.isVisible, !center else {
            Defaults[.popoverClosed] = false
            popoverShownAtLeastOnce = true
            window.show(at: point)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let button = statusItem.button else { return }

        popover.contentViewController = MainViewController()
        popover.contentViewController!.view = view
        popoverShownAtLeastOnce = true
        positioningView = NSView(frame: button.bounds)

        guard let positioningView else { return }
        positioningView.identifier = NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        button.addSubview(positioningView)

        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .maxY)
        positioningView.bounds = positioningView.bounds.offsetBy(dx: 0, dy: positioningView.bounds.height)
        if let popoverWindow = popoverWindow {
            popoverWindow.setFrame(popoverWindow.frame.offsetBy(dx: 0, dy: 12), display: false)
            popoverWindow.makeKeyAndOrderFront(sender)
        }
        NSApp.activate(ignoringOtherApps: true)

        eventMonitor?.start()
    }

    @objc public func hidePopover(_ sender: AnyObject) {
        window.close()
        popover.performClose(sender)
        popover.contentViewController = nil
        eventMonitor?.stop()
    }

    // MARK: Internal

    var positioningView: NSView?
    var tryc = 0

    func mouseEventHandler(_ event: NSEvent?) {
        if popover.isShown, !shouldLeavePopoverOpen {
            hidePopover(LowtechAppDelegate.instance)
        }
    }

    // MARK: Private

    private var statusBar: NSStatusBar
    private var eventMonitor: GlobalEventMonitor?
}

// MARK: - MainViewController

public class MainViewController: NSViewController {}

// MARK: - PopoverBackgroundView

class PopoverBackgroundView: NSView {
    override func draw(_: NSRect) {
        NSColor.clear.set()
        bounds.fill()
    }
}

extension NSVisualEffectView {
    private typealias UpdateLayer = @convention(c) (AnyObject) -> Void

    @objc dynamic
    func replacement() {
        super.updateLayer()
        guard identifier == TRANSPARENT_POPOVER_IDENTIFIER, let layer = layer, layer.name == "NSPopoverFrame"
        else {
            unsafeBitCast(
                updateLayerOriginalIMP, to: Self.UpdateLayer.self
            )(self)
            return
        }
        CATransaction.begin()
        CATransaction.disableActions()

        layer.isOpaque = false
        layer.sublayers?.first?.opacity = 0
        if let window = window {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.styleMask = .borderless
            window.hasShadow = false

            if window.identifier == AUTO_X_POPOVER_IDENTIFIER, let screenFrame = NSScreen.main?.visibleFrame {
                #if DEBUG
                    print("window.frame: x=\(window.frame.origin.x) y=\(window.frame.origin.y) width=\(window.frame.height) width=\(window.frame.height)")
                    print("screenFrame: x=\(screenFrame.origin.x) y=\(screenFrame.origin.y) width=\(screenFrame.width) height=\(screenFrame.height)")
                #endif

                var xOffset: CGFloat = 0
                let maxAllowedWindowX = (screenFrame.width + screenFrame.origin.x) - window.frame.width

                if window.frame.origin.x > maxAllowedWindowX {
                    xOffset = -(window.frame.origin.x - maxAllowedWindowX)
                }

                if window.frame.origin.x < screenFrame.origin.x {
                    xOffset = (screenFrame.origin.x - window.frame.origin.x) + 20
                }

                #if DEBUG
                    print("maxAllowedWindowX: \(maxAllowedWindowX)")
                    print("xOffset: \(xOffset)")
                #endif

                if xOffset != 0 {
                    window.setFrame(window.frame.offsetBy(dx: xOffset, dy: 0), display: false)
                }
            }
        }

        CATransaction.commit()
    }
}

var updateLayerOriginal: Method?
var updateLayerOriginalIMP: IMP?
var popoverSwizzled = false

func swizzlePopoverBackground() {
    guard !popoverSwizzled else {
        return
    }
    popoverSwizzled = true
    let origMethod = #selector(NSVisualEffectView.updateLayer)
    let replacementMethod = #selector(NSVisualEffectView.replacement)

    updateLayerOriginal = class_getInstanceMethod(NSVisualEffectView.self, origMethod)
    updateLayerOriginalIMP = method_getImplementation(updateLayerOriginal!)

    let swizzleMethod: Method? = class_getInstanceMethod(NSVisualEffectView.self, replacementMethod)
    let swizzleImpl = method_getImplementation(swizzleMethod!)
    method_setImplementation(updateLayerOriginal!, swizzleImpl)
}

let TRANSPARENT_POPOVER_IDENTIFIER = NSUserInterfaceItemIdentifier("TRANSPARENT_POPOVER")
let AUTO_X_POPOVER_IDENTIFIER = NSUserInterfaceItemIdentifier("AUTO_X_POPOVER")

func removePopoverBackground(view: NSView, backgroundView: inout PopoverBackgroundView?) {
    if let frameView = view.window?.contentView?.superview as? NSVisualEffectView {
        frameView.identifier = TRANSPARENT_POPOVER_IDENTIFIER
        if let window = view.window {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.styleMask = .borderless
            window.hasShadow = false
        }

        swizzlePopoverBackground()
        frameView.bg = .clear
        if backgroundView == nil {
            backgroundView = PopoverBackgroundView(frame: frameView.bounds)
            backgroundView!.autoresizingMask = NSView.AutoresizingMask([.width, .height])
            frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
        }
    }
}

// MARK: - HostingView

open class HostingView<T: View>: NSHostingView<T> {
    // MARK: Open

    override open func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removePopoverBackground(view: self, backgroundView: &backgroundView)
    }

    // MARK: Internal

    var backgroundView: PopoverBackgroundView?
}
