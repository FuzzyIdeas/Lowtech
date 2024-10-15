import AppKit
import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI

extension NSButton {
    override open var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

extension NSSegmentedControl {
    override open var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

// MARK: - WindowModifierView

class WindowModifierView: NSView {
    init(_ modifier: @escaping (NSWindow) -> Void) {
        self.modifier = modifier
        super.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var modifier: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        if let window, let modifier {
            modifier(window)
        }
        super.viewDidMoveToWindow()
    }
}

// MARK: - WindowModifier

struct WindowModifier: NSViewRepresentable {
    init(_ modifier: @escaping (NSWindow) -> Void) {
        self.modifier = modifier
    }

    var modifier: (NSWindow) -> Void

    func makeNSView(context: Self.Context) -> NSView { WindowModifierView(modifier) }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

public extension View {
    func windowModifier(_ modifier: @escaping (NSWindow) -> Void) -> some View {
        background(WindowModifier { window in modifier(window) })
    }
}

// MARK: - NotificationView

public struct NotificationView: View {
    public init(
        notificationLines: [String] = [],
        yesButtonText: String? = nil,
        noButtonText: String? = nil,
        buttonAction: ((Bool) -> Void)? = nil
    ) {
        _notificationLines = State(initialValue: notificationLines)
        _yesButtonText = State(initialValue: yesButtonText)
        _noButtonText = State(initialValue: noButtonText)
        _buttonAction = State(initialValue: buttonAction)
    }

    public var body: some View {
        let hasButtons = noButtonText != nil || yesButtonText != nil

        VStack(alignment: .leading) {
            ForEach(notificationLines, id: \.self) { line in
                if line.starts(with: "# ") {
                    Text(line.suffix(line.count - 2))
                        .font(.title.weight(.heavy))
                        .padding(.bottom, notificationLines.count > 1 ? 4 : 0)
                        .lineLimit(1)
                        .scaledToFit()
                } else if #available(macOS 12.0, *), let str = try? AttributedString(markdown: line) {
                    Text(str)
                        .font(.system(size: fontSize))
                        .padding(.leading, notificationLines.count > 1 ? 8 : 0)
                        .allowsTightening(true)
                } else {
                    Text(line.replacingOccurrences(of: "*", with: ""))
                        .font(.system(size: fontSize))
                        .padding(.horizontal, notificationLines.count > 1 ? 8 : 0)
                        .allowsTightening(true)
                }
            }
            if hasButtons {
                HStack {
                    if let noButtonText {
                        Button(noButtonText) {
                            buttonAction?(false)
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.7), textColor: .inverted))
                        .font(.system(size: 13, weight: .semibold))
                        .keyboardShortcut(KeyboardShortcut(.space))
                    }
                    Spacer()
                    if let yesButtonText {
                        Button(yesButtonText) {
                            buttonAction?(true)
                        }
                        .buttonStyle(FlatButton(color: Color.hotRed.opacity(0.9), textColor: .inverted))
                        .font(.system(size: 13, weight: .semibold))
                        .keyboardShortcut(KeyboardShortcut(.return))
                    }
                }.padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .padding(20)
        .background(
            .regularMaterial
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 4, x: 0, y: 3)
        .focusable(false)
        .padding(20)
    }

    @State var notificationLines: [String] = []
    @State var yesButtonText: String? = nil
    @State var noButtonText: String? = nil
    @State var buttonAction: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    let fontSize: CGFloat = 16
}

public extension Color {
    #if os(macOS)
        func blended(withFraction fraction: CGFloat, of color: Color) -> Color {
            let color1 = NSColor(self)
            let color2 = NSColor(color)

            guard let blended = color1.blended(withFraction: fraction, of: color2)
            else { return self }

            return Color(blended)
        }

    #elseif os(iOS)
        func blended(withFraction fraction: CGFloat, of color: Color) -> Color {
            let color1 = UIColor(self)
            let color2 = UIColor(color)

            var r1: CGFloat = 1.0, g1: CGFloat = 1.0, b1: CGFloat = 1.0, a1: CGFloat = 1.0
            var r2: CGFloat = 1.0, g2: CGFloat = 1.0, b2: CGFloat = 1.0, a2: CGFloat = 1.0

            color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

            return Color(UIColor(
                red: r1 * (1 - fraction) + r2 * fraction,
                green: g1 * (1 - fraction) + g2 * fraction,
                blue: b1 * (1 - fraction) + b2 * fraction,
                alpha: a1 * (1 - fraction) + a2 * fraction
            ))
        }
    #endif
}

// MARK: - Nameable

public protocol Nameable {
    var name: String { get set }
}

#if os(macOS)
    import Carbon
    import Cocoa
    import Magnet
    import Sauce

    public struct ScreenPlacementView: View {
        public init(screenPlacement: Binding<ScreenCorner?>) {
            _screenPlacement = screenPlacement
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Button("   ") { screenPlacement = .topLeft }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .topLeft))
                    Button("   ") { screenPlacement = .top }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .top))
                    Button("   ") { screenPlacement = .topRight }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .topRight))
                }
                HStack(alignment: .center, spacing: 10) {
                    Button("   ") { screenPlacement = .left }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .left))
                    Button("   ") { screenPlacement = .center }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .center))
                    Button("   ") { screenPlacement = .right }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .right))
                }
                HStack(alignment: .bottom, spacing: 10) {
                    Button("   ") { screenPlacement = .bottomLeft }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .bottomLeft))
                    Button("   ") { screenPlacement = .bottom }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .bottom))
                    Button("   ") { screenPlacement = .bottomRight }
                        .buttonStyle(PickerButton(enumValue: screenPlacement, onValue: .bottomRight))
                }
            }
        }

        @Binding var screenPlacement: ScreenCorner?
    }

    open class SizedPopUpButton: NSPopUpButton {
        override public var intrinsicContentSize: NSSize {
            guard let width, let height else {
                return super.intrinsicContentSize
            }

            return NSSize(width: width, height: height)
        }

        var width: CGFloat?
        var height: CGFloat?
    }

    // MARK: - PopUpButton

    public struct PopUpButton<T: Nameable>: NSViewRepresentable {
        open class Coordinator: NSObject {
            init(_ popUpButton: PopUpButton) {
                button = popUpButton
            }

            var button: PopUpButton
            var observer: Cancellable?
            lazy var defaultMenuItem: NSMenuItem = {
                let m = NSMenuItem(title: button.noValueText ?? "", action: nil, keyEquivalent: "")
                m.isHidden = true
                m.isEnabled = true
                m.identifier = NSUserInterfaceItemIdentifier("DEFAULT_MENU_ITEM")

                return m
            }()
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        public func makeMenuItems(context: Context) -> [NSMenuItem] {
            content.map { input -> NSMenuItem in
                let item = NSMenuItem(title: input.name, action: nil, keyEquivalent: "")
                item.identifier = NSUserInterfaceItemIdentifier(rawValue: input.name)

                return item
            } + [context.coordinator.defaultMenuItem]
        }

        public func makeNSView(context: Context) -> SizedPopUpButton {
            let button = SizedPopUpButton()
            button.width = width
            button.height = height

            button.bezelStyle = .inline
            button.imagePosition = .imageLeading
            button.usesSingleLineMode = true
            button.autoenablesItems = false

            let menu = NSMenu()
            menu.items = makeMenuItems(context: context)

            button.menu = menu
            button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
            context.coordinator.observer = button.selectionPublisher.sink { inputName in
                guard let inputName else { return }
                selection = content.first(where: { $0.name == inputName }) ?? selection
            }
            return button
        }

        public func updateNSView(_ button: SizedPopUpButton, context: Context) {
            guard let menu = button.menu else { return }
            menu.items = makeMenuItems(context: context)
            button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
            context.coordinator.observer = button.selectionPublisher.sink { inputName in
                guard let inputName else { return }
                selection = content.first(where: { $0.name == inputName }) ?? selection
            }

            button.width = width
            button.height = height
        }

        @Binding var selection: T
        @State var width: CGFloat?
        @State var height: CGFloat?
        @State var noValueText: String?

        @Binding var content: [T]
    }

    public struct DynamicKey: View {
        public init(
            key: Binding<SauceKey>,
            recording: Binding<Bool>? = nil,
            recordingColor: Color = Color.hotRed,
            darkHoverColor: Color = Color.hotRed,
            lightHoverColor: Color = Color.lunarYellow,
            allowedKeys: Set<SauceKey>? = nil,
            width: CGFloat? = nil
        ) {
            _key = key
            _recording = recording ?? .constant(false)

            self.recordingColor = recordingColor
            self.darkHoverColor = darkHoverColor
            self.lightHoverColor = lightHoverColor
            self.allowedKeys = allowedKeys

            _width = State(wrappedValue: width)
        }

        @Environment(\.isEnabled) public var isEnabled
        @Environment(\.font) public var font

        public var body: some View {
            Button(key.uppercasedChar) {
                if env.recording, !recording {
                    env.recording = false
                    return
                }
                recording.toggle()
            }.buttonStyle(
                FlatButton(
                    colorBinding: $color,
                    textColorBinding: $textColor.optional,
                    hoverColorBinding: $hoverColor.optional,
                    width: width
                )
            )
            .font(font?.monospaced() ?? .mono(13, weight: .bold))
            .colorMultiply(multiplyColor)
            .background(
                recording
                    ? KeyEventHandling(recording: $recording, key: $key, allowedKeys: allowedKeys)
                    : nil
            )
            .cornerRadius(6)
            .onHover { hovering in
                guard !recording, isEnabled else { return }
                withAnimation(.fastTransition) {
                    textColor = hovering ? (colorScheme == .dark ? .white : .gray) : Color.primary
                    color = hovering ? .white.opacity(0.2) : Color.primary.opacity(0.1)
                }
            }
            .onAppear { hoverColor = colorScheme == .dark ? darkHoverColor : lightHoverColor }
            .onChange(of: recording) { newRecording in
                env.recording = newRecording
                hoverColor = newRecording ? .white : (colorScheme == .dark ? darkHoverColor : lightHoverColor)
                textColor = newRecording ? .white : Color.primary
                color = newRecording ? .white.opacity(0.2) : Color.primary.opacity(0.1)
                withAnimation(.fastTransition) {
                    multiplyColor = newRecording ? recordingColor : .white
                }
            }
            .onChange(of: colorScheme) { hoverColor = $0 == .dark ? darkHoverColor : lightHoverColor }
            .onChange(of: env.recording) { newRecording in
                if recording, !newRecording {
                    recording = false
                }
            }
            .onDisappear { recording = false }
            .onExitCommand { recording = false }
            .opacity(isEnabled ? 1 : 0.6)
            .onReceive(NotificationCenter.default.publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)) { _ in
                forceUpdate.toggle()
            }
        }

        public static func keyString(_ keyCode: Int) -> String {
            Sauce.shared.character(for: keyCode, cocoaModifiers: []) ?? SauceKey(QWERTYKeyCode: keyCode)?.character ?? ""
        }

        var darkHoverColor = Color.hotRed
        var lightHoverColor = Color.lunarYellow
        var recordingColor = Color.hotRed
        var allowedKeys: Set<SauceKey>?

        @EnvironmentObject var env: EnvState
        @Environment(\.colorScheme) var colorScheme

        @Binding var key: SauceKey
        @Binding var recording: Bool

        @State var multiplyColor = Color.white
        @State var color = Color.primary.opacity(0.1)
        @State var textColor = Color.primary
        @State var hoverColor = Color.primary

        @State var width: CGFloat? = nil

        @State private var forceUpdate = false

    }

    // MARK: - KeyEventHandling

    public struct KeyEventHandling: NSViewRepresentable {
        public init(
            recording: Binding<Bool>,
            key: Binding<SauceKey>,
            allowedKeys: Set<SauceKey>? = nil,
            onCancel: (() -> Void)? = nil
        ) {
            _recording = recording
            _key = key

            self.allowedKeys = allowedKeys
            self.onCancel = onCancel
        }

        open class Coordinator: NSObject {
            init(_ handler: KeyEventHandling) {
                eventHandler = handler
            }

            var eventHandler: KeyEventHandling
        }

        open class KeyView: NSView {
            override public var acceptsFirstResponder: Bool { true }

            override public func keyDown(with event: NSEvent) {
                guard let context, let key = event.keyCombo?.key ?? SauceKey(QWERTYKeyCode: event.keyCode.i) else {
                    return
                }

                guard event.keyCode != kVK_Escape.u16 else {
                    #if DEBUG
                        print("Cancel Recording")
                    #endif

                    context.coordinator.eventHandler.recording = false
                    context.coordinator.eventHandler.onCancel?()
                    return
                }

                if let allowedKeys = context.coordinator.eventHandler.allowedKeys {
                    guard allowedKeys.contains(key) else { return }
                } else {
                    guard let letter = event.charactersIgnoringModifiers?.lowercased(), ALPHANUMERICS.contains(letter) else { return }
                }

                let letter = event.charactersIgnoringModifiers?.lowercased() ?? ""

                #if DEBUG
                    print("End Recording: \(letter)")
                #endif

                context.coordinator.eventHandler.recording = false
                context.coordinator.eventHandler.key = key
            }

            dynamic var context: Context?
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        public func makeNSView(context: Context) -> NSView {
            let view = KeyView()
            view.context = context

            if recording {
                DispatchQueue.main.async {
                    view.window?.makeFirstResponder(view)
                }
            }

            return view
        }

        public func updateNSView(_ nsView: NSView, context: Context) {
            guard let view = nsView as? KeyView else { return }
            view.context = context

            DispatchQueue.main.async {
                if recording {
                    view.window?.makeFirstResponder(view)
                } else {
                    view.resignFirstResponder()
                }
            }
        }

        @Binding var recording: Bool
        @Binding var key: SauceKey

        var allowedKeys: Set<SauceKey>?
        var onCancel: (() -> Void)?
    }

    public extension Set<Int> {
        static var NUMBER_KEYS: Set<Int> = Set(Set<CGKeyCode>.NUMBER_KEYS.map { Int($0) })
        static var FUNCTION_KEYS: Set<Int> = Set(Set<CGKeyCode>.FUNCTION_KEYS.map { Int($0) })
        static var ALPHANUMERIC_KEYS: Set<Int> = Set(Set<CGKeyCode>.ALPHANUMERIC_KEYS.map { Int($0) })
        static var SYMBOL_KEYS: Set<Int> = Set(Set<CGKeyCode>.SYMBOL_KEYS.map { Int($0) })
        static var ALPHA_KEYS: Set<Int> = Set(Set<CGKeyCode>.ALPHA_KEYS.map { Int($0) })
        static var ALL_KEYS: Set<Int> = Set(Set<CGKeyCode>.ALL_KEYS.map { Int($0) })
    }

    public extension SauceKey {
        static let NUMBER_KEYS: [SauceKey] = [
            SauceKey.zero, SauceKey.one, SauceKey.two, SauceKey.three, SauceKey.four, SauceKey.five, SauceKey.six, SauceKey.seven, SauceKey.eight, SauceKey.nine,
        ]
        static let FUNCTION_KEYS: [SauceKey] = [
            SauceKey.f1, SauceKey.f2, SauceKey.f3, SauceKey.f4, SauceKey.f5, SauceKey.f6, SauceKey.f7, SauceKey.f8, SauceKey.f9, SauceKey.f10, SauceKey.f11, SauceKey.f12,
            SauceKey.f13, SauceKey.f14, SauceKey.f15, SauceKey.f16, SauceKey.f17, SauceKey.f18, SauceKey.f19, SauceKey.f20,
        ]
        static let ALPHANUMERIC_KEYS: [SauceKey] = [
            SauceKey.zero, SauceKey.one, SauceKey.two, SauceKey.three, SauceKey.four, SauceKey.five, SauceKey.six, SauceKey.seven, SauceKey.eight, SauceKey.nine,
            SauceKey.q, SauceKey.w, SauceKey.e, SauceKey.r, SauceKey.t, SauceKey.y, SauceKey.u, SauceKey.i, SauceKey.o, SauceKey.p,
            SauceKey.a, SauceKey.s, SauceKey.d, SauceKey.f, SauceKey.g, SauceKey.h, SauceKey.j, SauceKey.k, SauceKey.l,
            SauceKey.z, SauceKey.x, SauceKey.c, SauceKey.v, SauceKey.b, SauceKey.n, SauceKey.m,
        ]

        static let SYMBOL_KEYS: [SauceKey] = [
            SauceKey.equal, SauceKey.minus, SauceKey.rightBracket, SauceKey.leftBracket,
            SauceKey.quote, SauceKey.semicolon, SauceKey.backslash, SauceKey.section,
            SauceKey.comma, SauceKey.slash, SauceKey.period, SauceKey.grave,
        ]

        static let ALPHA_KEYS: [SauceKey] = ALPHANUMERIC_KEYS.without(NUMBER_KEYS)
        static let ALL_KEYS: [SauceKey] = FUNCTION_KEYS + ALPHANUMERIC_KEYS + SYMBOL_KEYS
    }
    public extension Set<CGKeyCode> {
        static var NUMBER_KEYS: Set<CGKeyCode> = SauceKey.NUMBER_KEYS.map { Sauce.shared.keyCode(for: $0) }.set
        static var FUNCTION_KEYS: Set<CGKeyCode> = SauceKey.FUNCTION_KEYS.map { Sauce.shared.keyCode(for: $0) }.set
        static var ALPHANUMERIC_KEYS: Set<CGKeyCode> = SauceKey.ALPHANUMERIC_KEYS.map { Sauce.shared.keyCode(for: $0) }.set

        static var SYMBOL_KEYS: Set<CGKeyCode> = SauceKey.SYMBOL_KEYS.map { Sauce.shared.keyCode(for: $0) }.set

        static var ALPHA_KEYS: Set<CGKeyCode> = ALPHANUMERIC_KEYS.subtracting(.NUMBER_KEYS)
        static var ALL_KEYS: Set<CGKeyCode> = FUNCTION_KEYS.union(NUMBER_KEYS).union(ALPHANUMERIC_KEYS).union(SYMBOL_KEYS)
    }

    public extension Set<SauceKey> {
        static var NUMBER_KEYS: Set<SauceKey> = SauceKey.NUMBER_KEYS.set
        static var FUNCTION_KEYS: Set<SauceKey> = SauceKey.FUNCTION_KEYS.set
        static var ALPHANUMERIC_KEYS: Set<SauceKey> = SauceKey.ALPHANUMERIC_KEYS.set

        static var SYMBOL_KEYS: Set<SauceKey> = SauceKey.SYMBOL_KEYS.set

        static var ALPHA_KEYS: Set<SauceKey> = SauceKey.ALPHA_KEYS.set
        static var ALL_KEYS: Set<SauceKey> = SauceKey.ALL_KEYS.set
    }

    public struct MenuHotkeyView: View {
        public init(modifiers: [TriggerKey], key: SauceKey) {
            self.modifiers = modifiers
            self.key = key
        }

        public var modifiers: [TriggerKey]
        public var key: SauceKey

        public var body: some View {
            VStack(alignment: .center, spacing: 1) {
                HStack(alignment: .center) {
                    Text(modifiers.str)
                        .frame(minWidth: 16)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .foregroundColor(Color.bg.primary)
                        .background(Color.fg.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    Text(key.character.uppercased())
                        .frame(minWidth: 16)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .foregroundColor(Color.bg.primary)
                        .background(Color.fg.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                Text("Show this menu").font(.caption.bold())
            }
        }
    }

#endif

// MARK: - NamespaceWrapper

public class NamespaceWrapper: ObservableObject {
    public init(_ namespace: Namespace.ID) {
        self.namespace = namespace
    }

    public var namespace: Namespace.ID
}

// MARK: - EnvState

open class EnvState: ObservableObject {
    public init(recording: Bool = false, closed: Bool = true) {
        self.recording = recording
        self.closed = closed
    }

    @Published public var recording = false
    @Published public var closed = true

    public var menuHideTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    @Published var hoveringSlider = false
    @Published var draggingSlider = false
}

// MARK: - PopoverView

public struct PopoverView<Content: View>: View {
    public init(name: String, visible: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        _name = name.state
        _visible = visible
        self.content = content
    }

    public var body: some View {
        VStack {
            if SWIFTUI_PREVIEW || !env.closed {
                content().focusable(false).size(size: $size)
            } else {
                Color.clear.frame(width: size.width, height: size.height, alignment: .center)
            }
        }
        .onAppear { setup(visible) }
        .onChange(of: visible) { setup($0) }
    }

    let content: () -> Content

    @State var name: String
    @Binding var visible: Bool
    @EnvironmentObject var env: EnvState
    @State var size: CGSize = .zero

    func setup(_ visible: Bool? = nil) {
        guard visible ?? self.visible else {
            debug("Deallocating \(name) in 2 seconds...")
            env.menuHideTask = mainAsyncAfter(ms: 2000) {
                debug("Deallocated \(name)")
                env.closed = true
            }
            return
        }
        debug("Reallocating \(name)")
        env.menuHideTask = nil
        env.closed = false
    }
}

// MARK: - LowtechView

public struct LowtechView<Content: View>: View {
    public init(accentColor: Color, @ViewBuilder content: () -> Content) {
        self.content = content()
        _accentColor = accentColor.state
    }

    @Environment(\.colorScheme) public var colorScheme
    @State public var accentColor: Color = .hotRed

    @ViewBuilder public let content: Content

    public var body: some View {
        content
            .environmentObject(EnvState())
    }
}

public extension View {
    var any: AnyView { AnyView(self) }
}

// MARK: - PaddedPopoverView

public struct PaddedPopoverView<Content>: View where Content: View {
    public init(background: AnyView, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.background = background
    }

    public var body: some View {
        ZStack {
            background.scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    var background: AnyView
    @ViewBuilder let content: Content
}

// MARK: - ErrorPopoverView

public struct ErrorPopoverView: View {
    public init(error: Binding<String>) {
        _error = error
    }

    public var body: some View {
        ZStack {
            Color.hotRed.brightness(0.4).scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Error").font(.system(size: 24, weight: .heavy)).foregroundColor(.black).padding(.trailing)
                    Spacer()
                    SwiftUI.Button(
                        action: { error = "" },
                        label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18, weight: .semibold)) }
                    )
                    .buttonStyle(FlatButton(color: .clear, textColor: .black, circle: true))
                }
                ErrorTextView(error: error)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(.light)
        .onDisappear { error = "" }
    }

    @Binding var error: String
}

// MARK: - ErrorTextView

public struct ErrorTextView: View {
    public init(error: String) {
        _error = error.state
    }

    public var body: some View {
        Text(error).font(.system(size: 16, weight: .medium))
            .foregroundColor(.black)
            .frame(width: 340, alignment: .topLeading)
    }

    @State var error: String
}

// MARK: - EdgeBorder

public struct EdgeBorder: Shape {
    public var width: CGFloat
    public var edges: [Edge]

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: rect.minX - 0.5
                case .trailing: rect.maxX - width + 0.5
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: rect.minY - 0.5
                case .bottom: rect.maxY - width + 0.5
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: rect.width
                case .leading, .trailing: width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: width
                case .leading, .trailing: rect.height
                }
            }
            path.addPath(Path(CGRect(x: x, y: y, width: w, height: h)))
        }
        return path
    }
}

public extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }

    func onAnimationCompleted<Value: VectorArithmetic>(for value: Value, completion: @escaping () -> Void) -> ModifiedContent<Self, AnimationCompletionObserverModifier<Value>> {
        modifier(AnimationCompletionObserverModifier(observedValue: value, completion: completion))
    }
}

// MARK: - AnimationCompletionObserverModifier

// An animatable modifier that is used for observing animations for a given animatable value.
public struct AnimationCompletionObserverModifier<Value>: AnimatableModifier where Value: VectorArithmetic {
    public init(observedValue: Value, completion: @escaping () -> Void) {
        self.completion = completion
        animatableData = observedValue
        targetValue = observedValue
    }

    /// While animating, SwiftUI changes the old input value to the new target value using this property. This value is set to the old value until the animation completes.
    public var animatableData: Value {
        didSet {
            notifyCompletionIfFinished()
        }
    }

    public func body(content: Content) -> some View {
        /// We're not really modifying the view so we can directly return the original input value.
        content
    }

    /// The target value for which we're observing. This value is directly set once the animation starts. During animation, `animatableData` will hold the oldValue and is only updated to the target value once the animation completes.
    private var targetValue: Value

    /// The completion callback which is called once the animation completes.
    private var completion: () -> Void

    /// Verifies whether the current animation is finished and calls the completion callback if true.
    private func notifyCompletionIfFinished() {
        guard animatableData == targetValue else { return }

        /// Dispatching is needed to take the next runloop for the completion callback.
        /// This prevents errors like "Modifying state during view update, this will cause undefined behavior."
        DispatchQueue.main.async {
            completion()
        }
    }
}

// MARK: - HighlightedText

public struct HighlightedText: View {
    public init(text: String, indices: [Int], highlightColor: Color) {
        _text = State(initialValue: text)
        _indices = State(initialValue: indices)
        _highlightColor = State(initialValue: highlightColor)
    }

    public var body: some View {
        let indices = indices.filter { $0 < text.count }.sorted()
        let maxIdx = text.count - 1

        if indices.isEmpty {
            return Text(text)
        } else if indices.count == 1, let idx = indices.first {
            switch idx {
            case 0:
                return Text(text[0]).foregroundColor(highlightColor) + Text(text[1 ..< text.count])
            case maxIdx:
                return Text(text[0 ..< maxIdx]) + Text(text[maxIdx]).foregroundColor(highlightColor)
            default:
                return Text(text[0 ..< idx]) + Text(text[idx]).foregroundColor(highlightColor) + Text(text[(idx + 1) ..< text.count])
            }
        } else {
            var lastIdx = 1
            let first = indices.first!
            let last = indices.last!
            return indices.map { i in
                switch i {
                case 0:
                    return Text(text[i]).foregroundColor(highlightColor)
                case maxIdx:
                    return Text(text[lastIdx ..< maxIdx]) + Text(text[i]).foregroundColor(highlightColor)
                case first:
                    let t = Text(text[0 ..< i]) + Text(text[i]).foregroundColor(highlightColor)
                    lastIdx = i + 1
                    return t
                case last:
                    return Text(text[lastIdx ..< i]) + Text(text[i]).foregroundColor(highlightColor) + Text(text[i + 1 ..< text.count])
                default:
                    let t = Text(text[lastIdx ..< i]) + Text(text[i]).foregroundColor(highlightColor)
                    lastIdx = i + 1
                    return t
                }
            }.sum()
        }
    }

    @State var text: String
    @State var indices: [Int]
    @State var highlightColor: Color
}

// MARK: - VisualEffectBlur

public struct VisualEffectBlur: View {
    public init(
        material: NSVisualEffectView.Material = .headerView,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .followsWindowActiveState,
        appearance: NSAppearance? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.appearance = appearance
    }

    public var body: some View {
        Representable(
            material: material,
            blendingMode: blendingMode,
            state: state,
            appearance: appearance
        ).accessibility(hidden: true)
    }

    private var material: NSVisualEffectView.Material
    private var blendingMode: NSVisualEffectView.BlendingMode
    private var state: NSVisualEffectView.State
    private var appearance: NSAppearance?
}

// MARK: - Representable

extension VisualEffectBlur {
    struct Representable: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        var state: NSVisualEffectView.State
        var appearance: NSAppearance?

        func makeNSView(context: Context) -> NSVisualEffectView {
            context.coordinator.visualEffectView
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {
            context.coordinator.update(material: material)
            context.coordinator.update(blendingMode: blendingMode)
            context.coordinator.update(state: state)
            context.coordinator.update(appearance: appearance)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

    }

    class Coordinator {
        init() {
            visualEffectView.blendingMode = .withinWindow
        }

        let visualEffectView = NSVisualEffectView()

        func update(appearance: NSAppearance?) {
            visualEffectView.appearance = appearance
        }

        func update(material: NSVisualEffectView.Material) {
            visualEffectView.material = material
        }

        func update(blendingMode: NSVisualEffectView.BlendingMode) {
            visualEffectView.blendingMode = blendingMode
        }

        func update(state: NSVisualEffectView.State) {
            visualEffectView.state = state
        }
    }
}

public class SharingManager: ObservableObject {
    public init() {}

    @Published public var isShowingPicker = false
}

public struct SharingsPicker: NSViewRepresentable {
    public init(isPresented: Binding<Bool>, sharingItems: [Any]) {
        _isPresented = isPresented
        self.sharingItems = sharingItems
        picker = NSSharingServicePicker(items: sharingItems)
    }

    public class Coordinator: NSObject, NSSharingServicePickerDelegate {
        init(owner: SharingsPicker) {
            self.owner = owner
        }

        public var shown = false

        public func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            sharingServicePicker.delegate = nil
            mainActor { self.owner.isPresented = false }
        }

        let owner: SharingsPicker
    }

    @Binding public var isPresented: Bool
    public var sharingItems: [Any] = []

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented, !context.coordinator.shown, let picker {
            picker.delegate = context.coordinator
            context.coordinator.shown = true

            DispatchQueue.main.async {
                picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
            }
        }

        if !isPresented, context.coordinator.shown {
            context.coordinator.shown = false
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    private var picker: NSSharingServicePicker?

}
