import AppKit
import Cocoa
import Combine
import Defaults
import Foundation
import SwiftUI
import VisualEffects

public let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }
public let ALPHANUMERICS_SET = Set(ALPHANUMERICS)

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
                        .minimumScaleFactor(.leastNonzeroMagnitude)
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
                    if let noButtonText = noButtonText {
                        Button(noButtonText) {
                            buttonAction?(false)
                        }
                        .buttonStyle(FlatButton(color: .primary.opacity(0.7), textColor: colors.inverted))
                        .font(.system(size: 13, weight: .semibold))
                        .keyboardShortcut(KeyboardShortcut(.space))
                    }
                    Spacer()
                    if let yesButtonText = yesButtonText {
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
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 4, x: 0, y: 3)
        ).focusable(false)
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
            guard let width = width, let height = height else {
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
                guard let inputName = inputName else { return }
                selection = content.first(where: { $0.name == inputName }) ?? selection
            }
            return button
        }

        public func updateNSView(_ button: SizedPopUpButton, context: Context) {
            guard let menu = button.menu else { return }
            menu.items = makeMenuItems(context: context)
            button.select(menu.items.first(where: { $0.title == selection.name }) ?? context.coordinator.defaultMenuItem)
            context.coordinator.observer = button.selectionPublisher.sink { inputName in
                guard let inputName = inputName else { return }
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
            shouldStopRecording: Binding<Bool>? = nil,
            darkHoverColor: Color = Colors.red,
            lightHoverColor: Color = Colors.lunarYellow,
            allowedKeys: Set<String>? = nil,
            allowedKeyCodes: Set<Int>? = nil,
            fontSize: CGFloat = 13,
            width: CGFloat? = nil
        ) {
            _key = key
            _keyCode = keyCode
            _shouldStopRecording = shouldStopRecording ?? .constant(false)

            self.darkHoverColor = darkHoverColor
            self.lightHoverColor = lightHoverColor
            self.allowedKeys = allowedKeys
            self.allowedKeyCodes = allowedKeyCodes

            _fontSize = State(wrappedValue: fontSize)
            _width = State(wrappedValue: width)
        }

        // MARK: Public

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
            .colorMultiply(recordingColor)
            .background(recording ? KeyEventHandling(
                recording: $recording,
                key: $key,
                keyCode: $keyCode,
                allowedKeys: allowedKeys,
                allowedKeyCodes: allowedKeyCodes
            ) : nil)
            .cornerRadius(6)
            .onHover { hovering in
                guard !recording else { return }
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
                    recordingColor = newRecording ? Colors.red : .white
                }
            }
            .onChange(of: colorScheme) { hoverColor = $0 == .dark ? darkHoverColor : lightHoverColor }
            .onChange(of: shouldStopRecording) { if $0 { recording = false } }
            .onChange(of: env.recording) { newRecording in
                if recording, !newRecording {
                    recording = false
                }
            }
            .onDisappear { recording = false }
            .onExitCommand { recording = false }
        }

        public static func keyString(_ keyCode: Int) -> String {
            switch keyCode {
            case kVK_ANSI_0: return "0"
            case kVK_ANSI_1: return "1"
            case kVK_ANSI_2: return "2"
            case kVK_ANSI_3: return "3"
            case kVK_ANSI_4: return "4"
            case kVK_ANSI_5: return "5"
            case kVK_ANSI_6: return "6"
            case kVK_ANSI_7: return "7"
            case kVK_ANSI_8: return "8"
            case kVK_ANSI_9: return "9"
            default: return Key(QWERTYKeyCode: keyCode.i)?.rawValue.uppercased() ?? ""
            }
        }

        // MARK: Internal

        var darkHoverColor = Colors.red
        var lightHoverColor = Colors.lunarYellow
        var allowedKeys: Set<String>?
        var allowedKeyCodes: Set<Int>?

        @EnvironmentObject var env: EnvState
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.colors) var colors

        @Binding var key: String
        @Binding var keyCode: Int
        @Binding var shouldStopRecording: Bool

        @State var recordingColor = Color.white
        @State var color = Color.primary.opacity(0.1)
        @State var textColor = Color.primary
        @State var hoverColor = Color.primary

        @State var recording = false
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
            allowedKeyCodes: Set<Int>? = nil
        ) {
            _recording = recording
            _key = key
            _keyCode = keyCode

            self.allowedKeys = allowedKeys
            self.allowedKeyCodes = allowedKeyCodes
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
                guard let context = context else {
                    return
                }

                guard event.keyCode != kVK_Escape.u16 else {
                    #if DEBUG
                        print("Cancel Recording")
                    #endif

                    context.coordinator.eventHandler.recording = false
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
            DispatchQueue.main.async { // wait till next event cycle
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        public func updateNSView(_ nsView: NSView, context: Context) {
            (nsView as? KeyView)?.context = context
        }

        // MARK: Internal

        static let NUMBER_KEYS = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        ]
        static let FUNCTION_KEYS = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
            kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        static let ALPHANUMERIC_KEYS = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
            kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
            kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
            kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B, kVK_ANSI_N, kVK_ANSI_M,
        ]

        @Binding var recording: Bool
        @Binding var key: String
        @Binding var keyCode: Int

        var allowedKeys: Set<String>?
        var allowedKeyCodes: Set<Int>?
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

// MARK: - EnvState

open class EnvState: ObservableObject {
    // MARK: Lifecycle

    public init(recording: Bool = false) {
        self.recording = recording
    }

    // MARK: Public

    @Published public var recording = false
}

var menuHideTask: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

// MARK: - PopoverView

public struct PopoverView<Content: View>: View {
    // MARK: Lifecycle

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: Public

    @ViewBuilder public let content: Content

    public var body: some View {
        VStack {
            if !hidden {
                content.focusable(false)
            } else {
                EmptyView()
            }
        }.onChange(of: popoverClosed) { setup($0) }
    }

    // MARK: Internal

    @Default(.popoverClosed) var popoverClosed
    @State var hidden = false

    func setup(_ closed: Bool? = nil) {
        guard !(closed ?? popoverClosed) else {
            debug("Deallocating menu")
            menuHideTask = mainAsyncAfter(ms: 2000) { hidden = true }
            return
        }
        debug("Reallocating menu")
        menuHideTask = nil
        hidden = false
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

// MARK: - TrialOSDContainer

struct TrialOSDContainer: View {
    var body: some View {
        HStack {
            if let img = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading) {
                Text("Trial period of") + Text(" \(Bundle.main.name ?? "the app") ").bold() + Text("expired for the current session.")
                Text("Buy the full version from") + Text(" App Store ").bold() + Text("to remove this limitation.")
            }.fixedSize()
        }
        .padding()
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(radius: 6, x: 0, y: 3)
        )
        .padding()
    }
}
