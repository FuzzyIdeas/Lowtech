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
    public init(style: Style = .circle, scale: Image.Scale = .large, color: Color? = nil) {
        self.style = style
        self.scale = scale
        self.color = color
    }

    public enum Style {
        case square, circle

        public var sfSymbolName: String {
            switch self {
            case .square:
                "square"
            case .circle:
                "circle"
            }
        }
    }

    @Environment(\.isEnabled) public var isEnabled
    public let style: Style
    public let scale: Image.Scale
    public let color: Color?

    public func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle() // toggle the state binding
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.\(style.sfSymbolName).fill" : style.sfSymbolName)
                    .imageScale(scale)
                    .foregroundColor(color)
                configuration.label
            }
        })
        .buttonStyle(PlainButtonStyle()) // remove any implicit styling from the button
        .disabled(!isEnabled)
    }
}

// MARK: - DetailToggleStyle

public struct DetailToggleStyle: ToggleStyle {
    public init(style: Style = .circle) {
        self.style = style
    }

    public enum Style {
        case square, circle, empty

        public var sfSymbolName: String {
            switch self {
            case .empty:
                ""
            case .square:
                ".square"
            case .circle:
                ".circle"
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

    func roundbg(size: CGFloat = 2.5, color: Color = .inverted, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: size, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, padding: CGFloat = 2.5, color: Color = .inverted, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: padding, horizontalPadding: padding * 2.2, color: color, shadowSize: shadowSize, noFG: noFG))
    }

    func roundbg(radius: CGFloat = 5, verticalPadding: CGFloat = 2.5, horizontalPadding: CGFloat = 6, color: Color = .inverted, shadowSize: CGFloat = 0, noFG: Bool = false) -> some View {
        modifier(RoundBG(radius: radius, verticalPadding: verticalPadding, horizontalPadding: horizontalPadding, color: color, shadowSize: shadowSize, noFG: noFG))
    }
}

// MARK: - RoundBG

public struct RoundBG: ViewModifier {
    public func body(content: Content) -> some View {
        let verticalPadding = verticalPadding ?? radius / 2
        content
            .padding(.horizontal, horizontalPadding ?? verticalPadding * 2.2)
            .padding(.vertical, verticalPadding)
            .background(
                roundRect(radius, fill: color)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.75 : 0.25), radius: shadowSize, x: 0, y: shadowSize / 2)
            )
            .if(!noFG) { $0.foregroundColor(.primary) }
    }

    @Environment(\.colorScheme) var colorScheme

    var radius: CGFloat
    var verticalPadding: CGFloat?
    var horizontalPadding: CGFloat?
    var color: Color
    var shadowSize: CGFloat
    var noFG: Bool
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
    public init(
        isOn: Binding<Bool>,
        color: Color = Color.primary,
        scale: CGFloat = 1,
        radius: CGFloat? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        horizontalPadding: CGFloat = 8.0,
        verticalPadding: CGFloat = 4.0,
        noFG: Bool = false
    ) {
        _color = State(initialValue: color)
        _scale = State(initialValue: scale)
        _width = State(initialValue: width)
        _height = State(initialValue: height)
        _horizontalPadding = State(initialValue: horizontalPadding)
        _verticalPadding = State(initialValue: verticalPadding)
        _radius = radius?.state ?? (height != nil ? height! * 0.4 : 8).state
        _isOn = isOn
        _noFG = State(initialValue: noFG)
    }

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .if(!noFG) { $0.foregroundColor(isOn ? .inverted : .primary) }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                roundRect(radius, fill: bgColor)
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
            .opacity(isEnabled ? 1 : 0.6)
    }

    @State var color: Color = .primary
    @State var scale: CGFloat = 1
    @State var width: CGFloat? = nil
    @State var height: CGFloat? = nil
    @State var radius: CGFloat = 10
    @State var horizontalPadding: CGFloat = 8.0
    @State var verticalPadding: CGFloat = 4.0
    @State var hovering = false
    @State var noFG = false

    @Binding var isOn: Bool

    var bgColor: Color {
        hovering ? (isOn ? color.opacity(0.8) : color.opacity(0.2)) : (isOn ? color.opacity(0.75) : color.opacity(0.15))
    }
}

extension Color {
    var ns: NSColor {
        NSColor(self)
    }
}

// MARK: - PickerButton

public struct PickerButton<T: Equatable>: ButtonStyle {
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
        radius: CGFloat = 8,
        hoverColor: Color = .white.opacity(0.15),
        enumValue: Binding<T>,
        onValue: T
    ) {
        self.color = color
        self.onColor = onColor
        self.offColor = offColor
        self.offTextColor = offTextColor
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.radius = radius
        _enumValue = enumValue
        self.onValue = onValue

        self.onTextColor = onTextColor

        self.hoverColor = hoverColor
        hoverTextColor = hoverColor.ns.isLight() ? Color.black : Color.white
    }

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(
                hovering
                    ? hoverTextColor
                    : (
                        enumValue == onValue
                            ? (onTextColor ?? .inverted)
                            : offTextColor
                    )
            )
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: radius,
                    style: .continuous
                ).fill(
                    enumValue == onValue
                        ? onColor
                        : (
                            hovering
                                ? hoverColor
                                : (offColor ?? color.opacity(colorScheme == .dark ? 0.5 : 0.8))
                        )
                )
            )
            .brightness(hovering ? 0.05 : 0.0)
            .contrast(hovering ? 1.01 : 1.0)
            .scaleEffect(hovering ? 1.05 : 1.00)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                guard enumValue != onValue else {
                    hovering = false
                    return
                }
                withAnimation(.fastTransition) {
                    hovering = hover
                }
            })
            .onChange(of: enumValue) { v in
                if hovering, v == onValue {
                    hovering = false
                }
            }
            .onChange(of: isEnabled) { e in
                if !e {
                    withAnimation(.fastTransition) {
                        hovering = false
                    }
                }
            }
            .opacity(isEnabled ? 1 : 0.6)
    }

    @Environment(\.colorScheme) var colorScheme

    var color = Color.primary.opacity(0.15)
    var onColor: Color = .primary
    var offColor: Color? = nil
    var onTextColor: Color? = nil
    var offTextColor = Color.secondary
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var radius: CGFloat
    var hoverColor: Color
    var hoverTextColor: Color
    @State var hovering = false
    @Binding var enumValue: T
    var onValue: T
}

// MARK: - FlatButton

public struct FlatButton: ButtonStyle {
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
        shadowSize: CGFloat = 0,
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
        _shadowSize = shadowSize.state
        _stretch = State(initialValue: stretch)
        _hoverColorEffects = State(initialValue: hoverColorEffects)
        _hoverScaleEffects = State(initialValue: hoverScaleEffects)
    }

    @Environment(\.isEnabled) public var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(textColor ?? .inverted)
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
                    .shadow(radius: shadowSize, y: shadowSize * 0.66)
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
                pressedColor = hoverColor?.blended(withFraction: 0.5, of: .white) ?? color.blended(withFraction: 0.2, of: .accent)
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
            .opacity(isEnabled ? 1 : 0.6)
    }

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
    @State var shadowSize: CGFloat = 0
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
    public init(
        size: CGFloat = 13,
        verticalPadding: CGFloat = 4,
        horizontalPadding: CGFloat = 8,
        shake: Binding<Bool>? = nil
    ) {
        _size = State(initialValue: size)
        _shake = shake ?? .constant(false)
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: size, weight: .medium))
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                    .shadow(color: Color.blackMauve.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .modifier(ShakeEffect(shakes: shake ? 2 : 0))
            .animation(Animation.default.repeatCount(2).speed(1.5), value: shake)
    }

    @Environment(\.colorScheme) var colorScheme
    @State var size: CGFloat = 13
    @State var verticalPadding: CGFloat = 4
    @State var horizontalPadding: CGFloat = 8
    @Binding var shake: Bool
}

// MARK: - ShakeEffect

public struct ShakeEffect: GeometryEffect {
    public init(shakes: Int) {
        position = CGFloat(shakes)
    }

    public var position: CGFloat

    public var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: -5 * sin(position * 2 * .pi), y: 0))
    }
}

// MARK: - HelpTag

public struct HelpTag: View {
    public var body: some View {
        if isPresented {
            Text(text)
                .round(9)
                .roundbg(radius: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .fixedSize()
                .offset(offset)
                .zIndex(100)
        }
    }

    @Binding var isPresented: Bool

    var text: String
    var offset: CGSize

}

public extension View {
    func helpTag(isPresented: Binding<Bool>, alignment: Alignment = .center, offset: CGSize = .zero, _ text: String) -> some View {
        overlay(alignment: alignment) {
            HelpTag(isPresented: isPresented, text: text, offset: offset)
        }
    }
}
