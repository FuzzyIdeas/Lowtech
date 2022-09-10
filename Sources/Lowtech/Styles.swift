//
//  Styles.swift
//  Volum
//
//  Created by Alin Panaitiu on 16.12.2021.
//

// import DynamicColor
import Foundation
import SwiftUI

// MARK: - CheckboxToggleStyle

// import SystemColors

public struct CheckboxToggleStyle: ToggleStyle {
    // MARK: Lifecycle

    public init(style: Style = .circle, scale: Image.Scale = .large) {
        self.style = style
        self.scale = scale
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
    public let style: Style
    public let scale: Image.Scale

    public func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(scale)
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

    static func ultraLight(_ size: CGFloat) -> Font {
        .system(size: size, weight: .ultraLight, design: .default)
    }

    static func light(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .default)
    }

    static func thin(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .default)
    }

    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
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

    func ultraLight(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .ultraLight, design: .default))
    }

    func light(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .light, design: .default))
    }

    func thin(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .thin, design: .default))
    }

    func regular(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .regular, design: .default))
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

    func roundbg(size: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: size, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, padding: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: padding, horizontalPadding: padding * 2.2, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, verticalPadding: CGFloat = 2.5, horizontalPadding: CGFloat = 6, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding, color: color, shadowSize: shadowSize, noFG: noFG))
    }
}

// MARK: - RoundBG

public struct RoundBG: ViewModifier {
    // MARK: Public

    public func body(content: Content) -> some View {
        let verticalPadding = verticalPadding ?? radius / 2
        content
            .padding(.horizontal, horizontalPadding ?? verticalPadding * 2.2)
            .padding(.vertical, verticalPadding)
            .background(
                roundRect(radius, fill: color)
                    .shadow(color: .black.opacity(0.15), radius: shadowSize, x: 0, y: shadowSize / 2)
            )
            .if(!noFG) { $0.foregroundColor(color.textColor(colors: colors)) }
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    @State var radius: CGFloat
    @State var verticalPadding: CGFloat?
    @State var horizontalPadding: CGFloat?
    @State var color: Color
    @State var shadowSize: CGFloat
    @State var noFG: Bool
}

public extension View {
    func roundbg(size: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: size, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, padding: CGFloat = 2.5, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: padding, horizontalPadding: padding * 2.2, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, verticalPadding: CGFloat = 2.5, horizontalPadding: CGFloat = 6, color: Color = .primary, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding, color: color, shadowSize: shadowSize, noFG: noFG))
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
        color: Color = Color.primary,
        scale: CGFloat = 1,
        radius: CGFloat? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        horizontalPadding: CGFloat = 8.0,
        verticalPadding: CGFloat = 4.0
    ) {
        _color = State(initialValue: color)
        _scale = State(initialValue: scale)
        _width = State(initialValue: width)
        _height = State(initialValue: height)
        _horizontalPadding = State(initialValue: horizontalPadding)
        _verticalPadding = State(initialValue: verticalPadding)
        _radius = radius?.state ?? (height != nil ? height! * 0.4 : 8).state
        _isOn = isOn
    }

    // MARK: Public

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(fgColor(configuration))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                roundRect(radius, fill: bgColor(configuration))
                    .frame(width: width, height: height, alignment: .center)
            )
            .brightness(hovering ? 0.05 : 0.0)
            .contrast(hovering ? 1.02 : 1.0)
            .scaleEffect(configuration.isPressed ? 1.02 : (hovering ? 1.05 : 1))
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

    @State var color: Color = .primary
    @State var scale: CGFloat = 1
    @State var width: CGFloat? = nil
    @State var height: CGFloat? = nil
    @State var radius: CGFloat = 10
    @State var horizontalPadding: CGFloat = 8.0
    @State var verticalPadding: CGFloat = 4.0
    @State var hovering = false

    @Binding var isOn: Bool

    func bgColor(_ configuration: Configuration) -> Color {
        hovering ? (isOn ? color.opacity(0.9) : color.opacity(0.2)) : (isOn ? color : color.opacity(0.1))
    }

    func fgColor(_ configuration: Configuration) -> Color {
        let textColor = color.textColor(colors: colors)
//        return hovering ? (isOn ? textColor : .primary) : (isOn ? textColor : .primary)
        return isOn ? textColor : .primary
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
        stretch: Bool = false,
        hoverColorEffects: Bool = true,
        hoverScaleEffects: Bool = true
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
        _hoverColorEffects = State(initialValue: hoverColorEffects)
        _hoverScaleEffects = State(initialValue: hoverScaleEffects)
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
            .if(hoverColorEffects) {
                $0.brightness(hovering ? 0.05 : 0.0)
                    .contrast(hovering ? 1.01 : 1.0)
            }
            .if(hoverScaleEffects) {
                $0.scaleEffect(
                    configuration.isPressed || pressed
                        ? 1.02
                        : (hovering ? 1.05 : 1.00)
                )
            }
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
    @State var hoverColorEffects = true
    @State var hoverScaleEffects = true

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

    public init(
        size: CGFloat = 13,
        verticalPadding: CGFloat = 4,
        horizontalPadding: CGFloat = 8,
        shake: Binding<Bool>? = nil
    ) {
        _size = State(initialValue: size)
        _shake = shake ?? .constant(false)
    }

    // MARK: Public

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: size, weight: .medium))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                    .shadow(color: Colors.blackMauve.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .modifier(ShakeEffect(shakes: shake ? 2 : 0))
            .animation(Animation.default.repeatCount(2).speed(1.5), value: shake)
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @State var size: CGFloat = 13
    @State var verticalPadding: CGFloat = 4
    @State var horizontalPadding: CGFloat = 8
    @Binding var shake: Bool
}

// MARK: - ShakeEffect

public struct ShakeEffect: GeometryEffect {
    // MARK: Lifecycle

    public init(shakes: Int) {
        position = CGFloat(shakes)
    }

    // MARK: Public

    public var position: CGFloat

    public var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: -5 * sin(position * 2 * .pi), y: 0))
    }
}
