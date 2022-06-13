// import AXSwift

// struct AXWindow {
//    // MARK: Lifecycle
//
//    init?(from window: UIElement, runningApp: NSRunningApplication? = nil) {
//        guard let attrs = try? window.getMultipleAttributes(
//            .frame,
//            .fullScreen,
//            .title,
//            .position,
//            .main,
//            .minimized,
//            .size,
//            .identifier,
//            .subrole,
//            .role,
//            .focused
//        )
//        else {
//            return nil
//        }
//
//        let frame = attrs[.frame] as? NSRect ?? NSRect()
//
//        self.frame = frame
//        fullScreen = attrs[.fullScreen] as? Bool ?? false
//        title = attrs[.title] as? String ?? ""
//        position = attrs[.position] as? NSPoint ?? NSPoint()
//        main = attrs[.main] as? Bool ?? false
//        minimized = attrs[.minimized] as? Bool ?? false
//        focused = attrs[.focused] as? Bool ?? false
//        size = attrs[.size] as? NSSize ?? NSSize()
//        identifier = attrs[.identifier] as? String ?? ""
//        subrole = attrs[.subrole] as? String ?? ""
//        role = attrs[.role] as? String ?? ""
//
//        self.runningApp = runningApp
//    }
//
//    // MARK: Internal
//
//    let frame: NSRect
//    let fullScreen: Bool
//    let title: String
//    let position: NSPoint
//    let main: Bool
//    let minimized: Bool
//    let focused: Bool
//    let size: NSSize
//    let identifier: String
//    let subrole: String
//    let role: String
//    let runningApp: NSRunningApplication?
// }
//
// extension NSRunningApplication {
//    func windows() -> [AXWindow]? {
//        guard let app = Application(self) else { return nil }
//        do {
//            let wins = try app.windows()
//            return wins?.compactMap { AXWindow(from: $0, runningApp: self) }
//        } catch {
//            printerr("Can't get windows for app \(self): \(error)")
//            return nil
//        }
//    }
// }
