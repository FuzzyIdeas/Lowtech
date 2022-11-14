import AppKit
import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI
import VisualEffects

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

// MARK: - NotificationView

public struct NotificationView: View {
    // MARK: Lifecycle

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

    // MARK: Public

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
                        .buttonStyle(FlatButton(color: .primary.opacity(0.7), textColor: colors.inverted))
                        .font(.system(size: 13, weight: .semibold))
                        .keyboardShortcut(KeyboardShortcut(.space))
                    }
                    Spacer()
                    if let yesButtonText {
                        Button(yesButtonText) {
                            buttonAction?(true)
                        }
                        .buttonStyle(FlatButton(color: Colors.red.opacity(0.9), textColor: colors.inverted))
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
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 4, x: 0, y: 3)
        )
        .focusable(false)
        .padding(20)
    }

    // MARK: Internal

    @State var notificationLines: [String] = []
    @State var yesButtonText: String? = nil
    @State var noButtonText: String? = nil
    @State var buttonAction: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

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

    open class SizedPopUpButton: NSPopUpButton {
        // MARK: Public

        override public var intrinsicContentSize: NSSize {
            guard let width, let height else {
                return super.intrinsicContentSize
            }

            return NSSize(width: width, height: height)
        }

        // MARK: Internal

        var width: CGFloat?
        var height: CGFloat?
    }

    // MARK: - PopUpButton

    public struct PopUpButton<T: Nameable>: NSViewRepresentable {
        // MARK: Open

        open class Coordinator: NSObject {
            // MARK: Lifecycle

            init(_ popUpButton: PopUpButton) {
                button = popUpButton
            }

            // MARK: Internal

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

        // MARK: Public

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

        // MARK: Internal

        @Binding var selection: T
        @State var width: CGFloat?
        @State var height: CGFloat?
        @State var noValueText: String?

        @Binding var content: [T]
    }

    public struct DynamicKey: View {
        // MARK: Lifecycle

        public init(
            key: Binding<String>,
            keyCode: Binding<Int>,
            recording: Binding<Bool>? = nil,
            recordingColor: Color = Colors.red,
            darkHoverColor: Color = Colors.red,
            lightHoverColor: Color = Colors.lunarYellow,
            allowedKeys: Set<String>? = nil,
            allowedKeyCodes: Set<Int>? = nil,
            fontSize: CGFloat = 13,
            width: CGFloat? = nil
        ) {
            _key = key
            _keyCode = keyCode
            _recording = recording ?? .constant(false)

            self.recordingColor = recordingColor
            self.darkHoverColor = darkHoverColor
            self.lightHoverColor = lightHoverColor
            self.allowedKeys = allowedKeys
            self.allowedKeyCodes = allowedKeyCodes

            _fontSize = State(wrappedValue: fontSize)
            _width = State(wrappedValue: width)
        }

        // MARK: Public

        @Environment(\.isEnabled) public var isEnabled

        public var body: some View {
            Button(key.uppercased() ?! DynamicKey.keyString(keyCode)) {
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
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .colorMultiply(multiplyColor)
            .background(recording ? KeyEventHandling(
                recording: $recording,
                key: $key,
                keyCode: $keyCode,
                allowedKeys: allowedKeys,
                allowedKeyCodes: allowedKeyCodes
            ) : nil)
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
        }

        public static func keyString(_ keyCode: Int) -> String {
            SauceKey(QWERTYKeyCode: keyCode)?.character ?? ""
        }

        // MARK: Internal

        var darkHoverColor = Colors.red
        var lightHoverColor = Colors.lunarYellow
        var recordingColor = Color.red
        var allowedKeys: Set<String>?
        var allowedKeyCodes: Set<Int>?

        @EnvironmentObject var env: EnvState
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.colors) var colors

        @Binding var key: String
        @Binding var keyCode: Int
        @Binding var recording: Bool

        @State var multiplyColor = Color.white
        @State var color = Color.primary.opacity(0.1)
        @State var textColor = Color.primary
        @State var hoverColor = Color.primary

        @State var fontSize: CGFloat = 13
        @State var width: CGFloat? = nil
    }

    // MARK: - KeyEventHandling

    public struct KeyEventHandling: NSViewRepresentable {
        // MARK: Lifecycle

        public init(
            recording: Binding<Bool>,
            key: Binding<String>,
            keyCode: Binding<Int>,
            allowedKeys: Set<String>? = nil,
            allowedKeyCodes: Set<Int>? = nil,
            onCancel: (() -> Void)? = nil
        ) {
            _recording = recording
            _key = key
            _keyCode = keyCode

            self.allowedKeys = allowedKeys
            self.allowedKeyCodes = allowedKeyCodes
            self.onCancel = onCancel
        }

        // MARK: Open

        open class Coordinator: NSObject {
            // MARK: Lifecycle

            init(_ handler: KeyEventHandling) {
                eventHandler = handler
            }

            // MARK: Internal

            var eventHandler: KeyEventHandling
        }

        open class KeyView: NSView {
            // MARK: Public

            override public var acceptsFirstResponder: Bool { true }

            override public func keyDown(with event: NSEvent) {
                guard let context else {
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

                if let allowedKeyCodes = context.coordinator.eventHandler.allowedKeyCodes {
                    guard allowedKeyCodes.contains(event.keyCode.i) else { return }
                } else if let allowedKeys = context.coordinator.eventHandler.allowedKeys {
                    guard let letter = event.charactersIgnoringModifiers?.lowercased(), allowedKeys.contains(letter) else { return }
                } else {
                    guard let letter = event.charactersIgnoringModifiers?.lowercased(), ALPHANUMERICS.contains(letter) else { return }
                }

                let letter = event.charactersIgnoringModifiers?.lowercased() ?? ""

                #if DEBUG
                    print("End Recording: \(letter)")
                #endif

                context.coordinator.eventHandler.recording = false
                context.coordinator.eventHandler.key = letter
                context.coordinator.eventHandler.keyCode = event.keyCode.i
            }

            // MARK: Internal

            dynamic var context: Context?
        }

        // MARK: Public

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

        // MARK: Internal

        @Binding var recording: Bool
        @Binding var key: String
        @Binding var keyCode: Int

        var allowedKeys: Set<String>?
        var allowedKeyCodes: Set<Int>?
        var onCancel: (() -> Void)?
    }

    public extension Set<Int> {
        static let NUMBER_KEYS: Set<Int> = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        ]
        static let FUNCTION_KEYS: Set<Int> = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
            kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        static let ALPHANUMERIC_KEYS: Set<Int> = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
            kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
            kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
            kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B, kVK_ANSI_N, kVK_ANSI_M,
        ]

        static let SYMBOL_KEYS: Set<Int> = [
            kVK_ANSI_Equal, kVK_ANSI_Minus, kVK_ANSI_RightBracket, kVK_ANSI_LeftBracket,
            kVK_ANSI_Quote, kVK_ANSI_Semicolon, kVK_ANSI_Backslash, kVK_ISO_Section,
            kVK_ANSI_Comma, kVK_ANSI_Slash, kVK_ANSI_Period, kVK_ANSI_Grave,
        ]

        static let ALPHA_KEYS: Set<Int> = ALPHANUMERIC_KEYS.subtracting(.NUMBER_KEYS)
        static let ALL_KEYS: Set<Int> = FUNCTION_KEYS.union(NUMBER_KEYS).union(ALPHANUMERIC_KEYS).union(SYMBOL_KEYS)
    }

    public struct MenuHotkeyView: View {
        // MARK: Lifecycle

        public init(modifiers: Binding<[TriggerKey]>, key: Binding<String>) {
            _modifiers = modifiers
            _key = key
        }

        // MARK: Public

        @Environment(\.colors) public var colors

        @Binding public var modifiers: [TriggerKey]
        @Binding public var key: String

        public var body: some View {
            VStack(alignment: .center, spacing: 1) {
                HStack(alignment: .center) {
                    Text(modifiers.str)
                        .frame(minWidth: 16)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .foregroundColor(colors.bg.primary)
                        .background(colors.fg.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    Text(key.uppercased())
                        .frame(minWidth: 16)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .foregroundColor(colors.bg.primary)
                        .background(colors.fg.primary)
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
    // MARK: Lifecycle

    public init(_ namespace: Namespace.ID) {
        self.namespace = namespace
    }

    // MARK: Public

    public var namespace: Namespace.ID
}

// MARK: - EnvState

open class EnvState: ObservableObject {
    // MARK: Lifecycle

    public init(recording: Bool = false, closed: Bool = true) {
        self.recording = recording
        self.closed = closed
    }

    // MARK: Public

    @Published public var recording = false
    @Published public var closed = true

    public var menuHideTask: DispatchWorkItem? {
        didSet { oldValue?.cancel() }
    }

    // MARK: Internal

    @Published var hoveringSlider = false
    @Published var draggingSlider = false
}

// MARK: - PopoverView

public struct PopoverView<Content: View>: View {
    // MARK: Lifecycle

    public init(name: String, visible: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        _name = name.state
        _visible = visible
        self.content = content
    }

    // MARK: Public

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

    // MARK: Internal

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
    // MARK: Lifecycle

    public init(accentColor: Color, @ViewBuilder content: () -> Content) {
        self.content = content()
        _accentColor = accentColor.state
    }

    // MARK: Public

    @Environment(\.colorScheme) public var colorScheme
    @State public var accentColor: Color = .red

    @ViewBuilder public let content: Content

    public var body: some View {
        content
            .environmentObject(EnvState())
            .colors(Colors(colorScheme, accent: accentColor))
    }
}

public extension View {
    var any: AnyView { AnyView(self) }
}

// MARK: - PaddedPopoverView

public struct PaddedPopoverView<Content>: View where Content: View {
    // MARK: Lifecycle

    public init(background: AnyView, @ViewBuilder content: () -> Content) {
        self.content = content()
        _background = background.state
    }

    // MARK: Public

    public var body: some View {
        ZStack {
            background.scaleEffect(1.5)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.preferredColorScheme(.light)
    }

    // MARK: Internal

    @State var background: AnyView
    @ViewBuilder let content: Content
}

// MARK: - ErrorPopoverView

public struct ErrorPopoverView: View {
    // MARK: Lifecycle

    public init(error: Binding<String>) {
        _error = error
    }

    // MARK: Public

    public var body: some View {
        ZStack {
            Color.red.brightness(0.4).scaleEffect(1.5)
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

    // MARK: Internal

    @Binding var error: String
}

// MARK: - ErrorTextView

public struct ErrorTextView: View {
    // MARK: Lifecycle

    public init(error: String) {
        _error = error.state
    }

    // MARK: Public

    public var body: some View {
        Text(error).font(.system(size: 16, weight: .medium))
            .foregroundColor(.black)
            .frame(width: 340, alignment: .topLeading)
    }

    // MARK: Internal

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
                case .top, .bottom, .leading: return rect.minX - 0.5
                case .trailing: return rect.maxX - width + 0.5
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY - 0.5
                case .bottom: return rect.maxY - width + 0.5
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return self.width
                case .leading, .trailing: return rect.height
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
    // MARK: Lifecycle

    public init(observedValue: Value, completion: @escaping () -> Void) {
        self.completion = completion
        animatableData = observedValue
        targetValue = observedValue
    }

    // MARK: Public

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

    // MARK: Private

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
            self.completion()
        }
    }
}
