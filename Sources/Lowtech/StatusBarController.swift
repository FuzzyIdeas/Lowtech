import AppKit
import Combine
import Defaults
import SwiftUI

public extension NSNotification.Name {
    static let closePopover: NSNotification.Name = .init("closePopover")
    static let openPopover: NSNotification.Name = .init("openPopover")
}

// MARK: - StatusBarDelegate

class StatusBarDelegate: NSObject, NSWindowDelegate {
    convenience init(statusBarController: StatusBarController) {
        self.init()
        self.statusBarController = statusBarController
    }

    var statusBarController: StatusBarController!

    @MainActor
    func windowDidMove(_ notification: Notification) {
        guard let window = statusBarController.window, window.isVisible, let position = statusBarController.position else { return }

        window.show(at: position, animate: true)
    }
}

// MARK: - StatusBarController

@MainActor
open class StatusBarController: NSObject, NSWindowDelegate, ObservableObject {
    public init(_ view: @autoclosure @escaping () -> AnyView, image: String = "MenubarIcon", length: CGFloat = NSStatusItem.squareLength) {
        self.view = view

        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: length)

        super.init()
        delegate = StatusBarDelegate(statusBarController: self)
        statusItem.button?.window?.delegate = delegate

        NotificationCenter.default.publisher(for: .closePopover)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { _ in self.hidePopover(LowtechAppDelegate.instance) }
            .store(in: &observers)
        NotificationCenter.default.publisher(for: .openPopover)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { _ in self.showPopover(LowtechAppDelegate.instance) }
            .store(in: &observers)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .debounce(for: .milliseconds(10), scheduler: RunLoop.main)
            .sink { _ in
                guard self.statusItem.isVisible else { return }
                self.hidePopover(LowtechAppDelegate.instance)
            }
            .store(in: &observers)

        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(named: image)
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true

            statusBarButton.action = #selector(statusItemClick(sender:))
            statusBarButton.target = self
        }

        if Defaults[.hideMenubarIcon], let statusBarButton = statusItem.button {
            statusBarButton.image = nil
            statusItem.isVisible = false
        }

        Defaults.publisher(.hideMenubarIcon).removeDuplicates().filter { $0.oldValue != $0.newValue }.sink { [self] hidden in
            let showingMenubarIcon = !hidden.newValue
            let hidingMenubarIcon = hidden.newValue

            hidePopover(self)
            statusItem.isVisible = showingMenubarIcon
            statusItem.button?.image = hidingMenubarIcon ? nil : NSImage(named: image)

            guard popoverShownAtLeastOnce else { return }
            mainAsyncAfter(ms: 10) {
                self.showPopover(self)
            }
        }.store(in: &observers)

        eventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
        dragEventMonitorLocal = LocalEventMonitor(mask: [.leftMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp]) { self.dragHandler($0) }
        dragEventMonitorLocal.start()
        dragEventMonitorGlobal = GlobalEventMonitor(mask: [.leftMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp]) { ev in
            guard self.draggingWindow else {
                return
            }

            self.draggingWindow = false
            if self.changedWindowScreen {
                self.changedWindowScreen = false
                NotificationCenter.default.post(name: .mainScreenChanged, object: nil)
            }
        }
        dragEventMonitorGlobal.start()

        NSApp.publisher(for: \.mainMenu).sink { _ in self.fixMenu() }
            .store(in: &observers)
    }

    open func windowWillClose(_: Notification) {
        debug("windowWillClose")
        if !Defaults[.popoverClosed] {
            Defaults[.popoverClosed] = true
        }
    }

    public var view: () -> AnyView
    public var screenObserver: Cancellable?
    public var observers: Set<AnyCancellable> = []
    public var statusItem: NSStatusItem
    @Atomic public var popoverShownAtLeastOnce = false
    @Atomic public var shouldLeavePopoverOpen = false
    @Atomic public var shouldDestroyWindowOnClose = true

    @Published public var storedPosition: CGPoint = .zero
    public var onWindowCreation: ((PanelWindow) -> Void)?
    public var centerOnScreen = false
    public var screenCorner: ScreenCorner?
    public var margin: CGFloat?

    @Atomic public var changedWindowScreen = false
    @Atomic public var draggingWindow = false

    public var allowPopover = true

    public var window: PanelWindow? {
        didSet {
            window?.allowToBecomeKey = true
            window?.delegate = self

            oldValue?.forceClose()

            if let window {
                screenObserver = NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: window)
                    .sink { _ in
                        guard !self.draggingWindow else {
                            self.changedWindowScreen = true
                            return
                        }
                        NotificationCenter.default.post(name: .mainScreenChanged, object: nil)
                    }
            } else {
                screenObserver = nil
            }
            guard let onWindowCreation, let window else { return }
            onWindowCreation(window)
        }
    }

    public var position: CGPoint? {
        guard !centerOnScreen, let button = statusItem.button, let screen = NSScreen.main,
              let menuBarIconPosition = button.window?.convertPoint(toScreen: button.frame.origin),
              let window, let viewSize = window.contentView?.frame.size
        else { return nil }

        var middle = CGPoint(
            x: menuBarIconPosition.x - viewSize.width / 2,
            y: screen.visibleFrame.maxY - (window.frame.height + 1)
        )

        if middle.x + window.frame.width > screen.visibleFrame.maxX {
            middle = CGPoint(x: screen.visibleFrame.maxX - window.frame.width, y: middle.y)
        } else if middle.x < screen.visibleFrame.minX {
            middle = CGPoint(x: screen.visibleFrame.minX, y: middle.y)
        }

        if storedPosition != middle {
            storedPosition = middle
        }
        return middle
    }

    @objc public func statusItemClick(sender: AnyObject) {
        draggingWindow = false
        togglePopover(sender: sender)
        draggingWindow = false
    }

    @objc public func togglePopover(sender: AnyObject) {
        if let window, window.isVisible {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    public func showPopoverIfNotVisible() {
        guard window == nil || !window!.isVisible else { return }
        showPopover(self)

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

    public func showPopover(_: AnyObject) {
        LowtechAppDelegate.instance.env.menuHideTask = nil
        postBeginMenuTrackingNotification()

        Defaults[.popoverClosed] = false
        popoverShownAtLeastOnce = true

        if window == nil {
            window = PanelWindow(swiftuiView: view(), styleMask: [.fullSizeContentView, .nonactivatingPanel, .utilityWindow], collectionBehavior: [.canJoinAllSpaces, .fullScreenDisallowsTiling, .transient])
        }
        guard statusItem.isVisible else {
            if allowPopover {
                window!.show(at: centerOnScreen ? nil : .mouseLocation(centeredOn: window), activate: true, corner: screenCorner, margin: margin)
                focus()
            } else {
                LowtechAppDelegate.instance.onPopoverNotAllowed()
            }
            return
        }

        if allowPopover {
            window!.show(at: position, activate: true, corner: screenCorner, margin: margin)
            mainAsyncAfter(ms: 10) {
                self.window!.show(at: self.position, activate: true, corner: self.screenCorner, margin: self.margin)
            }
            focus()
        } else {
            LowtechAppDelegate.instance.onPopoverNotAllowed()
        }
        eventMonitor?.start()
    }

    @objc public func hidePopover(_: AnyObject) {
        LowtechAppDelegate.instance.env.menuHideTask = nil
        postEndMenuTrackingNotification()

        guard let window else { return }
        window.close()
        eventMonitor?.stop()
        NSApp.deactivate()

        guard shouldDestroyWindowOnClose else { return }
        LowtechAppDelegate.instance.env.menuHideTask = mainAsyncAfter(ms: 2000) {
            self.window?.contentView = nil
            self.window?.forceClose()
            self.window = nil
        }
    }

    var dragEventMonitorLocal: LocalEventMonitor!
    var dragEventMonitorGlobal: GlobalEventMonitor!

    var delegate: StatusBarDelegate?

    func dragHandler(_ ev: NSEvent) -> NSEvent? {
        switch ev.type {
        case .leftMouseDown:
            draggingWindow = true
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            draggingWindow = false
            if changedWindowScreen {
                changedWindowScreen = false
                NotificationCenter.default.post(name: .mainScreenChanged, object: nil)
            }
        default:
            break
        }
        return ev
    }

    func mouseEventHandler(_ event: NSEvent) {
        guard let window, event.window == nil else { return }
        if window.isVisible, statusItem.isVisible, !shouldLeavePopoverOpen {
            hidePopover(LowtechAppDelegate.instance)
        }
    }

    private var statusBar: NSStatusBar
    private var eventMonitor: GlobalEventMonitor?
}

/// Posting this notification causes the system Menu Bar to stay put when the cursor leaves its area while over a full screen app.
func postBeginMenuTrackingNotification() {
    DistributedNotificationCenter.default().post(name: .init("com.apple.HIToolbox.beginMenuTrackingNotification"), object: nil)
}

/// Posting this notification reverses the effect of the notification above.
func postEndMenuTrackingNotification() {
    DistributedNotificationCenter.default().post(name: .init("com.apple.HIToolbox.endMenuTrackingNotification"), object: nil)
}
