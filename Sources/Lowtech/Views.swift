import AppKit
import Cocoa
import Combine
import Foundation
import SwiftUI
import VisualEffects

let ALPHANUMERICS = (
    CharacterSet.decimalDigits.characters().filter(\.isASCII) + CharacterSet.lowercaseLetters.characters()
        .filter(\.isASCII)
).map { String($0) }

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

struct NotificationView: View {
    @State var notificationLines: [String] = []
    @State var yesButtonText: String? = nil
    @State var noButtonText: String? = nil

    @State var buttonAction: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    let fontSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(notificationLines, id: \.self) { line in
                if line.starts(with: "# ") {
                    Text(line.suffix(line.count - 2))
                        .font(.title.weight(.heavy))
                        .padding(.bottom, 4)
                } else if #available(macOS 12.0, *), let str = try? AttributedString(markdown: line) {
                    Text(str)
                        .font(.system(size: fontSize))
                        .padding(.leading, 8)
                } else {
                    Text(line)
                        .font(.system(size: fontSize))
                        .padding(.horizontal, 8)
                }
            }
            HStack {
                if let noButtonText = noButtonText {
                    Button(noButtonText) {
                        buttonAction?(false)
                    }
                    .buttonStyle(FlatButton(color: .primary.opacity(0.7), textColor: colors.bg.primary))
                    .font(.system(size: 13, weight: .semibold))
                    .keyboardShortcut(KeyboardShortcut(.space))
                }
                Spacer()
                if let yesButtonText = yesButtonText {
                    Button(yesButtonText) {
                        buttonAction?(true)
                    }
                    .buttonStyle(FlatButton(color: Colors.red.opacity(0.9), textColor: colors.bg.primary))
                    .font(.system(size: 13, weight: .semibold))
                    .keyboardShortcut(KeyboardShortcut(.return))
                }
            }.padding(.horizontal, 8)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                .cornerRadius(18)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .shadow(color: Colors.blackMauve.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 4, x: 0, y: 3)
        )
    }
}

extension Color {
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

protocol Nameable {
    var name: String { get set }
}

#if os(macOS)
    import Carbon
    import Cocoa
    import Magnet

    class SizedPopUpButton: NSPopUpButton {
        var width: CGFloat?
        var height: CGFloat?

        override var intrinsicContentSize: NSSize {
            guard let width = width, let height = height else {
                return super.intrinsicContentSize
            }

            return NSSize(width: width, height: height)
        }
    }

    // MARK: - PopUpButton

    struct PopUpButton<T: Nameable>: NSViewRepresentable {
        class Coordinator: NSObject {
            // MARK: Lifecycle

            init(_ popUpButton: PopUpButton) {
                button = popUpButton
            }

            // MARK: Internal

            var button: PopUpButton
            var observer: Cancellable?
        }

        @Binding var selection: T
        @State var width: CGFloat?
        @State var height: CGFloat?

        var content: [T]

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeNSView(context: Context) -> SizedPopUpButton {
            let button = SizedPopUpButton()
            button.width = width
            button.height = height

            button.bezelStyle = .inline
            button.imagePosition = .imageLeading
            button.usesSingleLineMode = true
            button.autoenablesItems = false

            let menu = NSMenu()
            menu.items = content.map { input -> NSMenuItem in
                let item = NSMenuItem(title: input.name, action: nil, keyEquivalent: "")
                item.identifier = NSUserInterfaceItemIdentifier(rawValue: input.name)

                return item
            }

            button.menu = menu
            button.select(menu.items.first(where: { $0.title == selection.name }))
            context.coordinator.observer = button.selectionPublisher.sink { inputName in
                guard let inputName = inputName else { return }
                selection = content.first(where: { $0.name == inputName }) ?? selection
            }
            return button
        }

        func updateNSView(_ button: SizedPopUpButton, context: Context) {
            guard let menu = button.menu else { return }
            button.select(menu.items.first(where: { $0.title == selection.name }))
            context.coordinator.observer = button.selectionPublisher.sink { inputName in
                guard let inputName = inputName else { return }
                selection = content.first(where: { $0.name == inputName }) ?? selection
            }

            button.width = width
            button.height = height
        }
    }

    // MARK: - KeyEventHandling

    struct KeyEventHandling: NSViewRepresentable {
        class Coordinator: NSObject {
            // MARK: Lifecycle

            init(_ handler: KeyEventHandling) {
                eventHandler = handler
            }

            // MARK: Internal

            var eventHandler: KeyEventHandling
        }

        class KeyView: NSView {
            dynamic var context: Context?

            override var acceptsFirstResponder: Bool { true }

            override func keyDown(with event: NSEvent) {
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
                guard let letter = event.charactersIgnoringModifiers?.lowercased(), ALPHANUMERICS.contains(letter) else { return }

                #if DEBUG
                    print("End Recording: \(letter)")
                #endif

                context.coordinator.eventHandler.recording = false
            }
        }

        @Binding var recording: Bool
        @Binding var hotkey: HotKey

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeNSView(context: Context) -> NSView {
            let view = KeyView()
            view.context = context
            DispatchQueue.main.async { // wait till next event cycle
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            (nsView as? KeyView)?.context = context
        }
    }
#endif

// MARK: - EnvState

class EnvState: ObservableObject { @Published var recording = false }

// MARK: - LowtechView

struct LowtechView<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        content
            .environmentObject(EnvState())
            .colors(Colors(colorScheme, accent: Colors.red))
    }
}
