import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"

public extension Notification.Name {
    static let mainScreenChanged = Notification.Name("MainScreenChanged")
}

// MARK: - LowtechAppDelegate

open class LowtechAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published open var showPopoverOnSpecialKey = true

    open var initialized = false
    open var env = EnvState()

    open func isTrialMode() -> Bool {
        false
    }

    @MainActor
    open func applicationDidBecomeActive(_ notification: Notification) {
        guard didBecomeActiveAtLeastOnce else {
            didBecomeActiveAtLeastOnce = true
            return
        }

        if Defaults[.hideMenubarIcon] {
            statusBar?.showPopoverIfNotVisible()
        }
    }

    @MainActor
    open func onAppearanceChanged(_ appearance: NSAppearance) {}

    @MainActor
    open func initObservers() {
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name(rawValue: kAppleInterfaceThemeChangedNotification), object: nil)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { notification in
                NSAppearance.current = NSApp.effectiveAppearance
                self.onAppearanceChanged(NSAppearance.current)
            }.store(in: &observers)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: nil)
            .eraseToAnyPublisher().map { $0 as Any? }
            .merge(with: NSWorkspace.shared.publisher(for: \.frontmostApplication).eraseToAnyPublisher().map { $0 as Any? })
            .merge(
                with:
                NSWorkspace.shared.notificationCenter
                    .publisher(for: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
                    .eraseToAnyPublisher().map { $0 as Any? }
            )
            .sink { notification in
                NotificationCenter.default.post(name: .mainScreenChanged, object: nil)
            }.store(in: &observers)
    }

    @MainActor open func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            print(notification)
        #endif

        LowtechAppDelegate.instance = self
        Defaults[.launchCount] += 1

        initMenubar()
        initObservers()
        KM.onSpecialHotkey = { [self] in
            guard showPopoverOnSpecialKey else {
                return
            }

            statusBar?.togglePopover(sender: self)
        }
        KM.initHotkeys()
        KM.initFlagsListener()

        if Defaults[.launchCount] == 1, showPopoverOnFirstLaunch {
            mainAsyncAfter(ms: 1000) {
                guard let s = self.statusBar, s.window == nil || !s.window!.isVisible else { return }
                s.showPopover(self)
            }
        }
        initialized = true
        KM.initialized = true
    }

    @MainActor
    open func onPopoverNotAllowed() {}

    public private(set) static var instance: LowtechAppDelegate!

    public lazy var trialMode = isTrialMode()

    public var showPopoverOnFirstLaunch = true
    public var statusBar: StatusBarController?
    public var application = NSApplication.shared

    public var observers: Set<AnyCancellable> = []

    public var contentView: AnyView?
    public var accentColor: Color?

    public var appStoreURL: URL?

    public var notificationPopover: PanelWindow! {
        didSet {
            oldValue?.forceClose()
        }
    }

    public var notificationCloser: DispatchWorkItem? {
        didSet {
            guard let oldCloser = oldValue else {
                return
            }
            oldCloser.cancel()
        }
    }

    @MainActor
    public func hidePopover() {
        statusBar?.hidePopover(self)
    }

    @MainActor
    public func showNotification(
        title: String,
        lines: [String],
        yesButtonText: String? = nil,
        noButtonText: String? = nil,
        closeAfter closeMilliseconds: Int = 4000,
        menubarIconHidden: Bool? = nil,
        action: ((Bool) -> Void)? = nil
    ) {
        guard let screen = NSScreen.main else { return }
        let view = NotificationView(
            notificationLines: (title.isEmpty ? [] : ["# \(title)"]) + lines,
            yesButtonText: yesButtonText, noButtonText: noButtonText, buttonAction: action
        ).any
        notificationPopover = PanelWindow(swiftuiView: view)
        if notificationPopover.frame.height == 0 {
            notificationPopover.show(at: NSPoint(
                x: screen.visibleFrame.maxX,
                y: screen.visibleFrame.maxY - 100
            ), activate: false)
        }
        mainAsyncAfter(ms: 1) {
            self.notificationPopover.show(at: NSPoint(
                x: screen.visibleFrame.maxX - (self.notificationPopover?.contentView!.frame.width ?? 400),
                y: screen.visibleFrame.maxY - (self.notificationPopover?.contentView!.frame.height ?? 100)
            ), activate: false)
        }
        notificationCloser = mainAsyncAfter(ms: closeMilliseconds) {
            guard let notif = self.notificationPopover, notif.isVisible else { return }
            notif.forceClose()
        }
    }

    @MainActor
    public func initMenubar() {
        guard let contentView else {
            return
        }

        let color = accentColor ?? Colors.yellow
        statusBar = StatusBarController(
            LowtechView(accentColor: color) { contentView }.any
        )
    }

    private var didBecomeActiveAtLeastOnce = false

}
