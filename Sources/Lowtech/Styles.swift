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

// MARK: - OutlineButton

public struct OutlineButton: ButtonStyle {
    // MARK: Public

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
                withAnimation(.easeOut(duration: 0.2)) {
                    multiplyColor = hover ? hoverColor : .white
                    scale = hover ? 1.02 : 1.0
                }
            })
    }

    // MARK: Internal

    @State var color = Color.primary.opacity(0.8)
    @State var hoverColor = Color.primary
    @State var multiplyColor = Color.white
    @State var scale: CGFloat = 1
    @State var font: Font = .body.bold()
}

// MARK: - ToggleButton

public struct ToggleButton: ButtonStyle {
    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(isOn ? onTextColor : offTextColor)
            .padding(.vertical, 4.0)
            .padding(.horizontal, 8.0)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(isOn ? onColor : offColor)
                    .frame(width: width, height: height, alignment: .center)

            ).scaleEffect(scale).colorMultiply(hoverColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard isEnabled else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    hoverColor = hover ? colors.accent : .white
                    scale = hover ? 1.05 : 1.0
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @State var onColor = Color.primary
    @State var offColor = Color.primary.opacity(0.1)
    @State var onTextColor = Color.textBackground
    @State var offTextColor = Color.secondary
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
    @State var isEnabled = true
    @Binding var isOn: Bool
    @State var width: CGFloat? = nil
    @State var height: CGFloat? = nil
}

// MARK: - PickerButton

public struct PickerButton<T: Equatable>: ButtonStyle {
    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(enumValue == onValue ? onTextColor : offTextColor)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).fill(enumValue == onValue ? color : (offColor ?? color.opacity(0.2)))

            ).scaleEffect(scale).colorMultiply(hoverColor)
            .contentShape(Rectangle())
            .onHover(perform: { hover in
                guard enumValue != onValue else {
                    hoverColor = .white
                    scale = 1.0
                    return
                }
                withAnimation(.easeOut(duration: 0.1)) {
                    hoverColor = hover ? colors.accent : .white
                    scale = hover ? 1.05 : 1.0
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @State var color = Color.primary
    @State var offColor: Color? = nil
    @State var onTextColor = Color.textBackground
    @State var offTextColor = Color.secondary
    @State var horizontalPadding: CGFloat = 8
    @State var verticalPadding: CGFloat = 4
    @State var brightness = 0.0
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
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
        textColorBinding: Binding<Color>? = nil,
        hoverColorBinding: Binding<Color>? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        circle: Bool = false,
        radius: CGFloat = 8,
        pressedBinding: Binding<Bool>? = nil
    ) {
        _color = colorBinding ?? .constant(color ?? Colors.lightGold)
        _textColor = textColorBinding ?? .constant(textColor ?? Colors.blackGray)
        _hoverColor = hoverColorBinding ?? .constant(hoverColor ?? Colors.lightGold)
        _width = .constant(width)
        _height = .constant(height)
        _circle = .constant(circle)
        _radius = .constant(radius)
        _pressed = pressedBinding ?? .constant(false)
    }

    // MARK: Public

    public func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(textColor)
            .padding(.vertical, 4.0)
            .padding(.horizontal, 8.0)
            .frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
            .background(
                circle
                    ?
                    AnyView(
                        Circle().fill(color)
                            .frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
                    )
                    : AnyView(
                        RoundedRectangle(
                            cornerRadius: radius,
                            style: .continuous
                        ).fill(color).frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height, alignment: .center)
                    )

            ).colorMultiply(configuration.isPressed ? pressedColor : colorMultiply)
            .scaleEffect(configuration.isPressed ? 1.02 : scale)
            .onAppear {
                pressedColor = hoverColor.blended(withFraction: 0.5, of: .white)
            }
            .onChange(of: pressed) { newPressed in
                if newPressed {
                    withAnimation(.interactiveSpring()) {
                        colorMultiply = hoverColor
                        scale = 1.05
                    }
                } else {
                    withAnimation(.interactiveSpring()) {
                        colorMultiply = .white
                        scale = 1.0
                    }
                }
            }
            .onHover(perform: { hover in
                withAnimation(.easeOut(duration: 0.2)) {
                    colorMultiply = hover ? hoverColor : .white
                    scale = hover ? 1.05 : 1
                }
            })
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @Binding var color: Color
    @Binding var textColor: Color
    @State var colorMultiply: Color = .white
    @State var scale: CGFloat = 1.0
    @Binding var hoverColor: Color
    @State var pressedColor: Color = .white
    @Binding var width: CGFloat?
    @Binding var height: CGFloat?
    @Binding var circle: Bool
    @Binding var radius: CGFloat
    @Binding var pressed: Bool
}

// MARK: - PaddedTextFieldStyle

public struct PaddedTextFieldStyle: TextFieldStyle {
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

prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}
