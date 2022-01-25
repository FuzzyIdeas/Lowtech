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

struct CheckboxToggleStyle: ToggleStyle {
    enum Style {
        case square, circle

        // MARK: Internal

        var sfSymbolName: String {
            switch self {
            case .square:
                return "square"
            case .circle:
                return "circle"
            }
        }
    }

    @Environment(\.isEnabled) var isEnabled
    let style: Style // custom param

    func makeBody(configuration: Configuration) -> some View {
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

struct OutlineButton: ButtonStyle {
    @State var color = Color.primary.opacity(0.8)
    @State var hoverColor = Color.primary
    @State var multiplyColor = Color.white
    @State var scale: CGFloat = 1
    @State var font: Font = .body.bold()

    func makeBody(configuration: Configuration) -> some View {
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
}

// MARK: - ToggleButton

struct ToggleButton: ButtonStyle {
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

    func makeBody(configuration: Configuration) -> some View {
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
}

// MARK: - PickerButton

struct PickerButton<T: Equatable>: ButtonStyle {
    @Environment(\.colors) var colors

    @State var color = Color.primary
    @State var offColor: Color? = nil
    @State var onTextColor = Color.textBackground
    @State var offTextColor = Color.secondary
    @State var horizontalPadding: CGFloat = 4
    @State var verticalPadding: CGFloat = 8
    @State var brightness = 0.0
    @State var scale: CGFloat = 1
    @State var hoverColor = Color.white
    @Binding var enumValue: T
    @State var onValue: T

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(enumValue == onValue ? onTextColor : offTextColor)
            .padding(.vertical, horizontalPadding)
            .padding(.horizontal, verticalPadding)
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
}

// MARK: - FlatButton

struct FlatButton: ButtonStyle {
    // MARK: Lifecycle

    init(
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
        _color = colorBinding ?? .constant(color ?? Colors.red)
        _textColor = textColorBinding ?? .constant(textColor ?? Colors.blackGray)
        _hoverColor = hoverColorBinding ?? .constant(hoverColor ?? Colors.red)
        _width = .constant(width)
        _height = .constant(height)
        _circle = .constant(circle)
        _radius = .constant(radius)
        _pressed = pressedBinding ?? .constant(false)
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

    func makeBody(configuration: Configuration) -> some View {
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

            ).colorMultiply(colorMultiply)
            .scaleEffect(scale)
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
            // .gesture(
            //     DragGesture(minimumDistance: 0)
            //     #if os(macOS)
            //         .onChanged { _ in
            //             if scale == 1.05 {
            //                 withAnimation(.interactiveSpring()) {
            //                     colorMultiply = pressedColor
            //                     scale = 1.02
            //                 }
            //             }
            //         }.onEnded { _ in
            //             withAnimation(.interactiveSpring()) {
            //                 colorMultiply = hoverColor
            //                 scale = 1.05
            //             }
            //             onTap()
            //         }
            //     #elseif os(iOS)
            //         .onChanged { _ in
            //             if scale == 1 {
            //                 withAnimation(.interactiveSpring()) {
            //                     colorMultiply = hoverColor
            //                     scale = 1.05
            //                 }
            //             }
            //         }.onEnded { _ in
            //             withAnimation(.interactiveSpring()) {
            //                 colorMultiply = .white
            //                 scale = 1.0
            //             }
            //             onTap()
            //         }
            //     #endif
            // )
            .onHover(perform: { hover in
                withAnimation(.easeOut(duration: 0.2)) {
                    colorMultiply = hover ? hoverColor : .white
                    scale = hover ? 1.05 : 1
                }
            })
    }
}
