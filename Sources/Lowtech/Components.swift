import Combine
import Foundation
import SwiftUI

// MARK: - Semaphore

public struct Semaphore: View {
    public init() {}

    @State public var xVisible = false

    public var body: some View {
        HStack {
            Button(
                action: { LowtechAppDelegate.instance.hidePopover() },
                label: {
                    ZStack(alignment: .center) {
                        Circle().fill(Color.hotRed).frame(width: 14, height: 14, alignment: .center)
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                            .opacity(xVisible ? 1 : 0)
                    }
                }
            ).buttonStyle(.plain)
                .onHover { hover in withAnimation(.easeOut(duration: 0.15)) { xVisible = hover }}
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14, alignment: .center)
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14, alignment: .center)
        }
        .padding(.leading, -8)
        .padding(.top, -8)
        .focusable(false)
    }
}

// MARK: - VScrollView

public struct VScrollView<Content>: View where Content: View {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    @ViewBuilder public let content: Content

    public var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
            }
        }
    }
}

// MARK: - HorizontalScrollViewOffsetPreferenceKey

struct HorizontalScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - HorizontalScrollViewFullWidthPreferenceKey

struct HorizontalScrollViewFullWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - HorizontalScrollViewWidthPreferenceKey

struct HorizontalScrollViewWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - HScrollView

public struct HScrollView<Content: View>: View {
    public init(
        @ViewBuilder content: () -> Content,
        gradientOpacity: CGFloat = 1.0,
        scrollViewFullWidth: CGFloat = 0,
        scrollViewWidth: CGFloat = 0,
        scrollViewOffset: CGFloat = 0,
        gradientColor: Color? = nil,
        gradientRadius: CGFloat = 0
    ) {
        self.content = content()
        _gradientOpacity = gradientOpacity.state
        _scrollViewFullWidth = scrollViewFullWidth.state
        _scrollViewWidth = scrollViewWidth.state
        _scrollViewOffset = scrollViewOffset.state
        _gradientColor = gradientColor.state
        _gradientRadius = gradientRadius.state
    }

    @ViewBuilder public let content: Content

    public var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    content
                        .frame(height: geometry.size.height)
                        .frame(minWidth: geometry.size.width)
                    GeometryReader { proxy in
                        let offset = proxy.frame(in: .named("scroll")).minX
                        Color.clear
                            .preference(key: HorizontalScrollViewFullWidthPreferenceKey.self, value: proxy.size.width)
                            .preference(key: HorizontalScrollViewOffsetPreferenceKey.self, value: offset)
                    }
                    Color.clear
                        .preference(key: HorizontalScrollViewWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(HorizontalScrollViewOffsetPreferenceKey.self) { value in
                scrollViewOffset = value
                computeGradientOpacity()
            }
            .onPreferenceChange(HorizontalScrollViewFullWidthPreferenceKey.self) { value in
                scrollViewFullWidth = value
                computeGradientOpacity()
            }
            .onPreferenceChange(HorizontalScrollViewWidthPreferenceKey.self) { value in
                scrollViewWidth = value
                computeGradientOpacity()
            }

            if let gradientColor {
                LinearGradient(
                    colors: [gradientColor, gradientColor.opacity(0)],
                    startPoint: .trailing,
                    endPoint: UnitPoint(x: UnitPoint.trailing.x - 0.2, y: UnitPoint.center.y)
                )
                .if(gradientRadius > 0) { $0.clipShape(RoundedRectangle(cornerRadius: gradientRadius, style: .continuous)) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .opacity(gradientOpacity)
            }
        }
    }

    @State var gradientOpacity: CGFloat = 1.0
    @State var scrollViewFullWidth: CGFloat = 0
    @State var scrollViewWidth: CGFloat = 0
    @State var scrollViewOffset: CGFloat = 0
    @State var gradientColor: Color? = nil
    @State var gradientRadius: CGFloat = 0

    func computeGradientOpacity() {
        gradientOpacity = cap((scrollViewFullWidth + scrollViewOffset) - scrollViewWidth, minVal: 0, maxVal: 40) / 40.0
    }
}

// MARK: - HomekitSlider

public struct HomekitSlider: View {
    public init(
        percentage: Binding<Float>,
        sliderWidth: CGFloat = 80,
        sliderHeight: CGFloat = 160,
        imageSize: CGFloat = 22,
        radius: CGFloat = 24,
        image: String? = nil,
        color: Color? = nil,
        hoverColor: Color? = nil,
        backgroundColor: Color = .black.opacity(0.1)
    ) {
        _percentage = percentage
        _sliderWidth = sliderWidth.state
        _sliderHeight = sliderHeight.state
        _imageSize = imageSize.state
        _radius = radius.state
        _image = image.state
        _color = color.state
        _hoverColor = hoverColor.state
        _backgroundColor = backgroundColor.state
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(Color.black.opacity(0.1))
                Rectangle()
                    .foregroundColor(color ?? Color.accent)
                    .colorMultiply(colorMultiply)
                    .frame(height: geometry.size.height * percentage.cg)

                if let image {
                    Image(systemName: image)
                        .resizable()
                        .frame(width: imageSize, height: imageSize, alignment: .bottom)
                        .font(.body.weight(.medium))
                        .frame(width: sliderWidth, height: sliderHeight)
                        .foregroundColor(Color.white.opacity(0.4))
                        .blendMode(.exclusion)
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .cornerRadius(radius)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if scale == 1 {
                            HomekitSlider.sliderTouched = true
                            withAnimation(.interactiveSpring()) {
                                colorMultiply = hoverColor ?? Color.accent
                                scale = 1.05
                            }
                        }
                        percentage = cap(Float((geometry.size.height - value.location.y) / geometry.size.height), minVal: 0, maxVal: 1)
                    }.onEnded { value in
                        HomekitSlider.sliderTouched = false
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                        percentage = cap(Float((geometry.size.height - value.location.y) / geometry.size.height), minVal: 0, maxVal: 1)
                    }
            )
            .animation(.easeOut(duration: 0.1), value: percentage)
            .scaleEffect(scale)
            #if os(macOS)
                .onHover { hovering in
                    if hovering {
                        trackScrollWheel()
                    } else {
                        HomekitSlider.sliderTouched = false
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                        percentage = cap(percentage, minVal: 0, maxVal: 1)
                        subs.forEach { $0.cancel() }
                        subs.removeAll()
                    }
                }
            #endif

        }.frame(width: sliderWidth, height: sliderHeight)
    }

    @Atomic static var sliderTouched = false

    @Environment(\.colorScheme) var colorScheme

    @Binding var percentage: Float
    @State var sliderWidth: CGFloat = 80
    @State var sliderHeight: CGFloat = 160
    @State var imageSize: CGFloat = 22
    @State var radius: CGFloat = 24

    @State var image: String? = nil
    @State var color: Color? = nil
    @State var hoverColor: Color? = nil
    @State var backgroundColor: Color = .black.opacity(0.1)

    @State var colorMultiply: Color = .white
    @State var scale: CGFloat = 1.0
    @State var subs = Set<AnyCancellable>()

    #if os(macOS)
        func trackScrollWheel() {
            let pub = NSApp.publisher(for: \.currentEvent)
            pub
                .filter { event in event?.type == .scrollWheel }
                .throttle(
                    for: .milliseconds(20),
                    scheduler: DispatchQueue.main,
                    latest: true
                )
                .sink { event in
                    guard let event, event.deltaX == 0, event.scrollingDeltaY != 0 else {
                        HomekitSlider.sliderTouched = false
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                        percentage = cap(percentage, minVal: 0, maxVal: 1)
                        return
                    }
                    if scale == 1 {
                        HomekitSlider.sliderTouched = true
                        withAnimation(.interactiveSpring()) {
                            colorMultiply = hoverColor ?? Color.accent
                            scale = 1.05
                        }
                    }
                    let delta = Float(event.scrollingDeltaY) * (event.isDirectionInvertedFromDevice ? 1 : -1)
                    percentage = cap(percentage - (delta / 100), minVal: 0, maxVal: 1)
                }
                .store(in: &subs)
        }
    #endif
}

// MARK: - BigSurSlider

public struct BigSurSlider: View {
    public init(
        percentage: Binding<Float>,
        sliderWidth: CGFloat = 200,
        sliderHeight: CGFloat = 22,
        image: String? = nil,
        imageBinding: Binding<String?>? = nil,
        color: Color? = nil,
        colorBinding: Binding<Color?>? = nil,
        backgroundColor: Color = .black.opacity(0.1),
        backgroundColorBinding: Binding<Color>? = nil,
        knobColor: Color? = nil,
        knobColorBinding: Binding<Color?>? = nil,
        knobTextColor: Color? = nil,
        knobTextColorBinding: Binding<Color?>? = nil,
        imgColor: Color? = nil,
        showValue: Binding<Bool>? = nil,
        acceptsMouseEvents: Binding<Bool>? = nil,
        enableText: String? = nil,
        mark: Binding<Float>? = nil,
        enable: (() -> Void)? = nil
    ) {
        _knobColor = .constant(knobColor)
        _knobTextColor = .constant(knobTextColor)

        _percentage = percentage
        _sliderWidth = sliderWidth.state
        _sliderHeight = sliderHeight.state
        _image = imageBinding ?? .constant(image)
        _color = colorBinding ?? .constant(color)
        _showValue = showValue ?? .constant(false)
        _backgroundColor = backgroundColorBinding ?? .constant(backgroundColor)
        _acceptsMouseEvents = acceptsMouseEvents ?? .constant(true)
        _enableText = State(initialValue: enableText)
        _mark = mark ?? .constant(0)
        _imgColor = .constant(.black)

        _knobColor = knobColorBinding ?? colorBinding ?? .constant(knobColor ?? Color.saffron)
        _knobTextColor = knobTextColorBinding ?? .constant(knobTextColor ?? ((color ?? Color.saffron).textColor()))
        _imgColor = .constant(imgColor ?? color?.textColor() ?? Color.black)
        self.enable = enable
    }

    @Environment(\.isEnabled) public var isEnabled

    public var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width - sliderHeight
            let cgPercentage = cap(percentage, minVal: 0, maxVal: 1).cg

            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(backgroundColor)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(color ?? .accent)
                        .frame(width: cgPercentage == 1 ? geometry.size.width : w * cgPercentage + sliderHeight / 2)
                    if let image {
                        Image(systemName: image)
                            .resizable()
                            .frame(width: 12, height: 12, alignment: .center)
                            .font(.body.weight(.heavy))
                            .frame(width: sliderHeight - 7, height: sliderHeight - 7)
                            .foregroundColor(imgColor.opacity(imgColor.isLight ? 0.9 : 0.6))
                            .offset(x: 3, y: 0)
                    }
                    ZStack {
                        Circle()
                            .foregroundColor(knobColor)
                            .shadow(color: Color.blackMauve.opacity(percentage > 0.3 ? 0.3 : percentage.d), radius: 5, x: -1, y: 0)
                            .frame(width: sliderHeight, height: sliderHeight, alignment: .trailing)
                            .brightness(env.draggingSlider && hovering ? -0.2 : 0)
                        if showValue {
                            Text((percentage * 100).str(decimals: 0))
                                .foregroundColor(knobTextColor)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .allowsHitTesting(false)
                        }
                    }.offset(
                        x: cgPercentage * w,
                        y: 0
                    )
                    if mark > 0 {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Color.hotRed.opacity(0.7))
                            .frame(width: 3, height: sliderHeight - 5, alignment: .center)
                            .offset(
                                x: cap(mark, minVal: 0, maxVal: 1).cg * w,
                                y: 0
                            ).animation(.jumpySpring, value: mark)
                    }
                }
                .contrast(!isEnabled ? 0.4 : 1.0)
                .saturation(!isEnabled ? 0.4 : 1.0)

                if !isEnabled, hovering, let enableText, let enable {
                    SwiftUI.Button(enableText) {
                        enable()
                    }
                    .buttonStyle(FlatButton(
                        color: Color.hotRed.opacity(0.7),
                        textColor: .white,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    ))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .transition(.scale.animation(.fastSpring))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .cornerRadius(20)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard acceptsMouseEvents, isEnabled else { return }
                        if !env.draggingSlider {
                            if draggingSliderSetter == nil {
                                draggingSliderSetter = mainAsyncAfter(ms: 200) {
                                    env.draggingSlider = true
                                }
                            } else {
                                draggingSliderSetter = nil
                                env.draggingSlider = true
                            }
                        }

                        percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                    }
                    .onEnded { value in
                        guard acceptsMouseEvents, isEnabled else { return }
                        draggingSliderSetter = nil
                        percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                        env.draggingSlider = false
                    }
            )
            #if os(macOS)
            .onHover { hov in
                hovering = hov
                guard acceptsMouseEvents, isEnabled else { return }

                if hovering {
                    lastCursorPosition = NSEvent.mouseLocation
                    hoveringSliderSetter = mainAsyncAfter(ms: 200) {
                        guard lastCursorPosition != NSEvent.mouseLocation else { return }
                        env.hoveringSlider = hovering
                    }
                    trackScrollWheel()
                } else {
                    hoveringSliderSetter = nil
                    env.hoveringSlider = false
                }
            }
            #endif
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var env: EnvState

    @Binding var percentage: Float
    @State var sliderWidth: CGFloat = 200
    @State var sliderHeight: CGFloat = 22
    @Binding var image: String?
    @Binding var color: Color?
    @Binding var backgroundColor: Color
    @Binding var knobColor: Color?
    @Binding var knobTextColor: Color?
    @Binding var imgColor: Color
    @Binding var showValue: Bool

    @State var scrollWheelListener: Cancellable?

    @State var hovering = false
    @State var enableText: String? = nil
    @State var lastCursorPosition = NSEvent.mouseLocation
    @Binding var acceptsMouseEvents: Bool
    @Binding var mark: Float

    var enable: (() -> Void)?

    #if os(macOS)
        func trackScrollWheel() {
            guard scrollWheelListener == nil else { return }
            scrollWheelListener = NSApp.publisher(for: \.currentEvent)
                .filter { event in event?.type == .scrollWheel }
                .throttle(for: .milliseconds(20), scheduler: DispatchQueue.main, latest: true)
                .sink { event in
                    guard hovering, env.hoveringSlider, let event, event.momentumPhase.rawValue == 0 else {
                        if let event, event.scrollingDeltaX + event.scrollingDeltaY == 0, event.phase.rawValue == 0,
                           env.draggingSlider
                        {
                            env.draggingSlider = false
                        }
                        return
                    }

                    let delta = Float(event.scrollingDeltaX) * (event.isDirectionInvertedFromDevice ? -1 : 1)
                        + Float(event.scrollingDeltaY) * (event.isDirectionInvertedFromDevice ? 1 : -1)

                    switch event.phase {
                    case .changed, .began, .mayBegin:
                        if !env.draggingSlider {
                            env.draggingSlider = true
                        }
                    case .ended, .cancelled, .stationary:
                        if env.draggingSlider {
                            env.draggingSlider = false
                        }
                    default:
                        if delta == 0, env.draggingSlider {
                            env.draggingSlider = false
                        }
                    }
                    percentage = cap(percentage - (delta / 100), minVal: 0, maxVal: 1)
                }
        }
    #endif
}

extension NSEvent.Phase {
    var str: String {
        switch self {
        case .mayBegin: "mayBegin"
        case .began: "began"
        case .changed: "changed"
        case .stationary: "stationary"
        case .cancelled: "cancelled"
        case .ended: "ended"
        default:
            "phase(\(rawValue))"
        }
    }
}

var hoveringSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

var draggingSliderSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

// MARK: - UpDownButtons

public struct UpDownButtons: View {
    public init(
        radius: CGFloat = 24,
        size: CGFloat = 80,
        color: Color? = nil,
        textColor: Color = .black,
        onPress: @escaping (ButtonDirection) -> Void
    ) {
        _radius = radius.state
        _size = size.state
        _color = color.state
        _textColor = textColor.state
        _onPress = st(onPress)
    }

    public enum ButtonDirection {
        case down
        case up
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color ?? .accent)
                .frame(width: size, height: size * 2, alignment: .center)
                .zIndex(0)
            VStack(spacing: 0) {
                Button(
                    action: { onPress?(.up) },
                    label: { Image(systemName: "plus").font(.system(size: size / 3, weight: .black)) }
                )
                .buttonStyle(FlatButton(
                    color: color ?? .accent,
                    textColor: textColor,
                    width: size,
                    height: size,
                    radius: radius
                ))
                .zIndex(upZ)
                .onHover(perform: { hover in
                    if hover {
                        upZ = 2
                        downZ = 1
                    }
                })
                Button(
                    action: { onPress?(.down) },
                    label: { Image(systemName: "minus").font(.system(size: size / 3, weight: .black)) }
                )
                .buttonStyle(FlatButton(
                    color: color ?? .accent,
                    textColor: textColor,
                    width: size,
                    height: size,
                    radius: radius
                ))
                .zIndex(downZ)
                .onHover(perform: { hover in
                    if hover {
                        upZ = 1
                        downZ = 2
                    }
                })
            }
        }
    }

    @State var radius: CGFloat = 24
    @State var size: CGFloat = 80
    @State var color: Color? = nil
    @State var textColor: Color = .black
    @State var onPress: ((ButtonDirection) -> Void)? = nil

    @State var upZ: Double = 1
    @State var downZ: Double = 2
}

// MARK: - TextInputView

public struct TextInputView: View {
    public init(
        label: String,
        placeholder: String,
        data: Binding<String>,
        size: CGFloat = 13
    ) {
        _label = label.state
        _placeholder = placeholder.state
        _data = data
        _size = size.state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: size, weight: .semibold))
            TextField(placeholder, text: $data)
                .textFieldStyle(PaddedTextFieldStyle())
        }
    }

    @State var label: String
    @State var placeholder: String
    @Binding var data: String

    @State var size: CGFloat = 13
}

// MARK: - ValueInputView

public struct ValueInputView<T>: View {
    public init(
        label: String,
        placeholder: String,
        data: Binding<T>,
        size: CGFloat = 13,
        formatter: Formatter
    ) {
        _label = label.state
        _placeholder = placeholder.state
        _data = data
        _size = size.state
        _formatter = st(formatter)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: size, weight: .semibold))
            TextField(placeholder, value: $data, formatter: formatter)
                .textFieldStyle(PaddedTextFieldStyle())
        }
    }

    @State var label: String
    @State var placeholder: String
    @Binding var data: T
    @State var formatter: Formatter

    @State var size: CGFloat = 13
}
