//
//  Styles.swift
//  Volum
//
//  Created by Alin Panaitiu on 16.12.2021.
//

import DynamicColor
import Foundation
import SwiftUI
import SystemColors

// MARK: - CheckboxToggleStyle

public struct CheckboxToggleStyle: ToggleStyle {
    // MARK: Lifecycle

    public init(style: Style = .circle) {
        self.style = style
    }

    // MARK: Public

    public enum Style {
        case square, circle

        // MARK: Public

        public var sfSymbolName: String {
            switch self {
            case .square:
                return "square"
            case .circle:
                return "circle"
            }
        }
    }

    @Environment(\.isEnabled) public var isEnabled
    public let style: Style // custom param

    public func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(.large)
                configuration.label
            }
        })
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - DetailToggleStyle

public struct DetailToggleStyle: ToggleStyle {
    // MARK: Lifecycle

    public init(style: Style = .circle) {
        self.style = style
    }

    // MARK: Public

    public enum Style {
        case square, circle, empty

        // MARK: Public

        public var sfSymbolName: String {
            switch self {
            case .empty:
                return ""
            case .square:
                return ".square"
            case .circle:
                return ".circle"
            }
        }
    }

    @Environment(\.isEnabled) public var isEnabled
    public let style: Style // custom param

    public func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack(spacing: 3) {
                Image(
                    systemName: configuration
                        .isOn ? "arrowtriangle.up\(style.sfSymbolName).fill" : "arrowtriangle.down\(style.sfSymbolName).fill"
                )
                .imageScale(.medium)
                configuration.label
            }
        })
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - OutlineButton

public struct OutlineButton: ButtonStyle {
    // MARK: Lifecycle

    public init(
        color: Color = Color.primary.opacity(0.8),
        hoverColor: Color = Color.primary,
        multiplyColor: Color = Color.white,
        scale: CGFloat = 1,
        font: Font = .body.bold()
    ) {
        _color = State(initialValue: color)
        _hoverColor = State(initialValue: hoverColor)
        _multiplyColor = State(initialValue: multiplyColor)
        _scale = State(initialValue: scale)
        _font = State(initialValue: font)
    }

    // MARK: Public

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .font(font)
            .foregroundColor(color)
            .padding(.vertical, 2.0)
            .padding(.horizontal, 8.0)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(color, lineWidth: 2)
            ).scaleEffect(scale).colorMultiply(multiplyColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    multiplyColor = hover ? hoverColor : .white
                    scale = hover ? 1.02 : 1.0
                }
            })
            .onChange(of: isEnabled) { e in
                if !e {
                    withAnimation(.easeOut(duration: 0.2)) {
                        multiplyColor = .white
                        scale = 1.0
                    }
                }
            }
    }

    // MARK: Internal

    @State var color = Color.primary.opacity(0.8)
    @State var hoverColor: Color = .primary
    @State var multiplyColor: Color = .white
    @State var scale: CGFloat = 1
    @State var font: Font = .body.bold()
}

public extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func round(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func bold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func heavy(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func black(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }
}

public extension Text {
    func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Text {
        font(.system(size: size, weight: weight, design: .monospaced))
    }

    func round(_ size: CGFloat, weight: Font.Weight = .medium) -> Text {
        font(.system(size: size, weight: weight, design: .rounded))
    }

    func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Text {
        font(.system(size: size, weight: weight, design: .serif))
    }

    func medium(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .medium, design: .default))
    }

    func semibold(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .semibold, design: .default))
    }

    func bold(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .bold, design: .default))
    }

    func heavy(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .heavy, design: .default))
    }

    func black(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .black, design: .default))
    }

    func roundbg(size: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0) -> some View {
        modifier(RoundBG(size: size, color: color, shadowSize: shadowSize))
            .foregroundColor(color.textColor)
    }
}

// MARK: - RoundBG

public struct RoundBG: ViewModifier {
    // MARK: Public

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, size * 2.2)
            .padding(.vertical, size)
            .background(
                roundRect(size * 2, fill: color)
                    .shadow(color: .black.opacity(0.15), radius: shadowSize, x: 0, y: shadowSize / 2)
            )
    }

    // MARK: Internal

    @State var size: CGFloat
    @State var color: Color
    @State var shadowSize: CGFloat
}

public extension View {
    func roundbg(size: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0) -> some View {
        modifier(RoundBG(size: size, color: color, shadowSize: shadowSize))
    }

    func hfill(_ alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    func vfill(_ alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }

    func fill(_ alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

public func roundRect(_ radius: CGFloat, fill: Color) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(fill)
}

public func roundRect(_ radius: CGFloat, stroke: Color) -> some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .stroke(stroke)
}

// MARK: - ToggleButton

public struct ToggleButton: ButtonStyle {
    // MARK: Lifecycle

    public init(
        isOn: Binding<Bool>,
        onColor: Color = Color.primary,
        offColor: Color = Color.primary.opacity(0.1),
        onTextColor: Color = Color.textBackground,
        offTextColor: Color = Color.secondary,
        hoverColor: Color = Color.white.opacity(0.5),
        scale: CGFloat = 1,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        _onColor = State(initialValue: onColor)
        _offColor = State(initialValue: offColor)
        _onTextColor = State(initialValue: onTextColor)
        _offTextColor = State(initialValue: offTextColor)
        _scale = State(initialValue: scale)
        _width = State(initialValue: width)
        _height = State(initialValue: height)
        _isOn = isOn

        _hoverColor = State(initialValue: hoverColor)
        _hoverTextColor = State(initialValue: hoverColor.ns.isLight() ? Color.black : Color.white)
    }

    // MARK: Public

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor((hovering && !configuration.isPressed) ? hoverTextColor : fgColor(configuration))
            .padding(.vertical, 4.0)
            .padding(.horizontal, 8.0)
            .background(
                roundRect(8, fill: (hovering && !configuration.isPressed) ? hoverColor.opacity(isOn ? 1.0 : 0.5) : bgColor(configuration))
                    .frame(width: width, height: height, alignment: .center)
            )
            .brightness(hovering ? 0.05 : 0.0)
            .contrast(hovering ? 1.02 : 1.0)
            .scaleEffect(hovering ? 1.05 : 1)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    hovering = hover
                }
            }).onChange(of: isEnabled) { e in
                if !e {
                    withAnimation(.easeOut(duration: 0.1)) {
                        hovering = false
                    }
                }
            }
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @State var onColor: Color = .primary
    @State var offColor = Color.primary.opacity(0.1)
    @State var onTextColor: Color = .textBackground
    @State var offTextColor: Color = .secondary
    @State var hoverColor: Color
    @State var hoverTextColor: Color
    @State var scale: CGFloat = 1
    @State var width: CGFloat? = nil
    @State var height: CGFloat? = nil
    @State var hovering = false

    @Binding var isOn: Bool

    func bgColor(_ configuration: Configuration) -> Color {
        configuration.isPressed ? (isOn ? offColor : onColor) : (isOn ? onColor : offColor)
    }

    func fgColor(_ configuration: Configuration) -> Color {
        configuration.isPressed ? (isOn ? offTextColor : onTextColor) : (isOn ? onTextColor : offTextColor)
    }
}

extension Color {
    var ns: NSColor {
        NSColor(self)
    }
}

// MARK: - PickerButton

public struct PickerButton<T: Equatable>: ButtonStyle {
    // MARK: Lifecycle

    public init(
        color: Color = Color.primary.opacity(0.15),
        onColor: Color = .primary,
        offColor: Color? = nil,
        onTextColor: Color? = nil,
        offTextColor: Color = Color.secondary,
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        brightness: Double = 0.0,
        scale: CGFloat = 1,
        hoverColor: Color = .white.opacity(0.15),
        enumValue: Binding<T>,
        onValue: T
    ) {
        _color = color.state
        _onColor = onColor.state
        _offColor = offColor.state
        _offTextColor = offTextColor.state
        _horizontalPadding = horizontalPadding.state
        _verticalPadding = verticalPadding.state
        _brightness = brightness.state
        _scale = scale.state
        _enumValue = enumValue
        _onValue = st(onValue)

        _onTextColor = onTextColor.state

        _hoverColor = State(initialValue: hoverColor)
        _hoverTextColor = State(initialValue: hoverColor.ns.isLight() ? Color.black : Color.white)
    }

    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(
                hovering
                    ? hoverTextColor
                    : enumValue == onValue
                    ? (onTextColor ?? colors.inverted)
                    : offTextColor
            )
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(
                    enumValue == onValue
                        ? onColor
                        :
                        (hovering ? hoverColor : (offColor ?? color.opacity(colorScheme == .dark ? 0.5 : 0.8)))
                )
            )
            .brightness(hovering ? 0.05 : 0.0)
            .contrast(hovering ? 1.01 : 1.0)
            .scaleEffect(hovering ? 1.05 : 1.00)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard enumValue != onValue else {
                    hovering = false
                    return
                }
                withAnimation(.fastTransition) {
                    hovering = hover
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors
    @Environment(\.colorScheme) var colorScheme

    @State var color = Color.primary.opacity(0.15)
    @State var hovering = false
    @State var onColor: Color = .primary
    @State var offColor: Color? = nil
    @State var onTextColor: Color? = nil
    @State var offTextColor = Color.secondary
    @State var horizontalPadding: CGFloat = 8
    @State var verticalPadding: CGFloat = 4
    @State var brightness = 0.0
    @State var scale: CGFloat = 1
    @State var hoverColor: Color
    @State var hoverTextColor: Color
    @Binding var enumValue: T
    @State var onValue: T
}

// MARK: - FlatButton

public struct FlatButton: ButtonStyle {
    // MARK: Lifecycle

    public init(
        color: Color? = nil,
        textColor: Color? = nil,
        hoverColor: Color? = nil,
        colorBinding: Binding<Color>? = nil,
        textColorBinding: Binding<Color?>? = nil,
        hoverColorBinding: Binding<Color?>? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        circle: Bool = false,
        radius: CGFloat = 8,
        pressedBinding: Binding<Bool>? = nil,
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        stretch: Bool = false
    ) {
        _color = colorBinding ?? .constant(color ?? Color.primary)
        _textColor = textColorBinding ?? .constant(textColor)
        _hoverColor = hoverColorBinding ?? .constant(hoverColor)
        _width = .constant(width)
        _height = .constant(height)
        _circle = .constant(circle)
        _radius = .constant(radius)
        _pressed = pressedBinding ?? .constant(false)
        _horizontalPadding = horizontalPadding.state
        _verticalPadding = verticalPadding.state
        _stretch = State(initialValue: stretch)
    }

    // MARK: Public

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(textColor ?? colors.inverted)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(
                minWidth: width,
                idealWidth: width,
                maxWidth: stretch ? .infinity : nil,
                minHeight: height,
                idealHeight: height,
                alignment: .center
            )
            .background(
                bg.colorMultiply(configuration.isPressed || pressed ? pressedColor : .white)
            )
            .brightness(hovering ? 0.05 : 0.0)
            .contrast(hovering ? 1.01 : 1.0)
            .scaleEffect(
                configuration.isPressed || pressed
                    ? 1.02
                    : (hovering ? 1.05 : 1.00)
            )
            .onAppear {
                pressedColor = hoverColor?.blended(withFraction: 0.5, of: .white) ?? color.blended(withFraction: 0.2, of: colors.accent)
            }
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.fastTransition) {
                    hovering = hover
                }
            })
            .onChange(of: isEnabled) { e in
                if !e {
                    withAnimation(.fastTransition) {
                        hovering = false
                    }
                }
            }
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @Binding var color: Color
    @Binding var textColor: Color?
    @State var colorMultiply: Color = .white
    @State var scale: CGFloat = 1.0
    @Binding var hoverColor: Color?
    @State var pressedColor: Color = .white
    @Binding var width: CGFloat?
    @Binding var height: CGFloat?
    @Binding var circle: Bool
    @Binding var radius: CGFloat
    @Binding var pressed: Bool
    @State var horizontalPadding: CGFloat = 8
    @State var verticalPadding: CGFloat = 4
    @State var stretch = false
    @State var hovering = false

    var bg: some View {
        circle
            ?
            AnyView(
                Circle().fill(color)
                    .frame(
                        minWidth: width,
                        idealWidth: width,
                        maxWidth: stretch ? .infinity : nil,
                        minHeight: height,
                        idealHeight: height,
                        alignment: .center
                    )
            )
            : AnyView(
                RoundedRectangle(
                    cornerRadius: radius,
                    style: .continuous
                ).fill(color).frame(
                    minWidth: width,
                    idealWidth: width,
                    maxWidth: stretch ? .infinity : nil,
                    minHeight: height,
                    idealHeight: height,
                    alignment: .center
                )
            )
    }
}

// MARK: - PaddedTextFieldStyle

public struct PaddedTextFieldStyle: TextFieldStyle {
    // MARK: Lifecycle

    public init(size: CGFloat = 13) {
        _size = State(initialValue: size)
    }

    // MARK: Public

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: size, weight: .medium))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(colorScheme == .dark ? 0.2 : 0.9))
                    .shadow(color: Colors.blackMauve.opacity(0.1), radius: 3, x: 0, y: 2)
            )
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @State var size: CGFloat = 13
}
