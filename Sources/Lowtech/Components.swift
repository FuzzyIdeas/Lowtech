import Combine
import Foundation
import SwiftUI

// MARK: - VScrollView

public struct VScrollView<Content>: View where Content: View {
    // MARK: Lifecycle

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    // MARK: Public

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
    // MARK: Lifecycle

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

    // MARK: Public

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

            if let gradientColor = gradientColor {
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

    // MARK: Internal

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
    // MARK: Lifecycle

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

    // MARK: Public

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(Color.black.opacity(0.1))
                Rectangle()
                    .foregroundColor(color ?? colors.accent)
                    .colorMultiply(colorMultiply)
                    .frame(height: geometry.size.height * percentage.cg)

                if let image = image {
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
                            withAnimation(.interactiveSpring()) {
                                colorMultiply = hoverColor ?? colors.accent
                                scale = 1.05
                            }
                        }
                        percentage = cap(Float((geometry.size.height - value.location.y) / geometry.size.height), minVal: 0, maxVal: 1)
                    }.onEnded { _ in
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                    }
            )
            .animation(.easeOut(duration: 0.1), value: percentage)
            .scaleEffect(scale)
            #if os(macOS)
                .onHover { hovering in
                    if hovering {
                        trackScrollWheel()
                    } else {
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                        subs.forEach { $0.cancel() }
                        subs.removeAll()
                    }
                }
            #endif

        }.frame(width: sliderWidth, height: sliderHeight)
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

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
                    guard let event = event, event.deltaX == 0, event.scrollingDeltaY != 0 else {
                        withAnimation(.spring()) {
                            scale = 1.0
                            colorMultiply = .white
                        }
                        return
                    }
                    if scale == 1 {
                        withAnimation(.interactiveSpring()) {
                            colorMultiply = hoverColor ?? colors.accent
                            scale = 1.05
                        }
                    }
                    let delta = Float(event.scrollingDeltaY) * (event.isDirectionInvertedFromDevice ? 1 : -1)
                    self.percentage = cap(self.percentage - (delta / 100), minVal: 0, maxVal: 1)
                }
                .store(in: &subs)
        }
    #endif
}

// MARK: - BigSurSlider

public struct BigSurSlider: View {
    // MARK: Lifecycle

    public init(
        percentage: Binding<Float>,
        sliderWidth: CGFloat = 200,
        sliderHeight: CGFloat = 22,
        image: String? = nil,
        color: Color? = nil,
        backgroundColor: Color = .black.opacity(0.1)
    ) {
        _percentage = percentage
        _sliderWidth = sliderWidth.state
        _sliderHeight = sliderHeight.state
        _image = image.state
        _color = color.state
        _backgroundColor = backgroundColor.state
    }

    // MARK: Public

    public var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width - self.sliderHeight
            let cgPercentage = percentage.cg

            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(backgroundColor)
                Rectangle()
                    .foregroundColor(color ?? colors.accent)
                    .frame(width: 10)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(color ?? colors.accent)
                        .frame(width: w * cgPercentage + sliderHeight / 2)
                    if let image = image {
                        Image(systemName: image)
                            .resizable()
                            .frame(width: 12, height: 12, alignment: .center)
                            .font(.body.weight(.heavy))
                            .frame(width: sliderHeight - 7, height: sliderHeight - 7)
                            .foregroundColor(Color.black.opacity(0.5))
                            .offset(x: 3, y: 0)
                    }
                    ZStack {
                        Circle()
                            .foregroundColor(colorScheme == .dark ? colors.accent : Colors.darkGray)
                            .shadow(color: Colors.blackMauve.opacity(percentage > 0.5 ? 0.5 : percentage.d), radius: 5, x: -1, y: 0)
                            .frame(width: sliderHeight, height: sliderHeight, alignment: .trailing)

                        Text((percentage * 100).str(decimals: 0))
                            .foregroundColor(colorScheme == .dark ? Colors.darkGray : Color.white)
                            .font(.system(size: 9, weight: .heavy))
                            .allowsHitTesting(false)
                    }.offset(
                        x: cgPercentage * w,
                        y: 0
                    )
                }
            }
            .frame(width: sliderWidth, height: sliderHeight)
            .cornerRadius(20)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        self.percentage = cap(Float(value.location.x / geometry.size.width), minVal: 0, maxVal: 1)
                    }
            )
            .animation(.easeOut(duration: 0.1), value: percentage)
            #if os(macOS)
                .onHover { hovering in
                    if hovering {
                        trackScrollWheel()
                    } else {
                        subs.forEach { $0.cancel() }
                        subs.removeAll()
                    }
                }
            #endif

        }.frame(width: sliderWidth, height: sliderHeight)
    }

    // MARK: Internal

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colors) var colors

    @Binding var percentage: Float
    @State var sliderWidth: CGFloat = 200
    @State var sliderHeight: CGFloat = 22
    @State var image: String? = nil
    @State var color: Color? = nil
    @State var backgroundColor: Color = .black.opacity(0.1)

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
                    guard let event = event, event.deltaY == 0 else { return }
                    let delta = Float(event.scrollingDeltaX) * (event.isDirectionInvertedFromDevice ? -1 : 1)
                    self.percentage = cap(self.percentage - (delta / 100), minVal: 0, maxVal: 1)
                }
                .store(in: &subs)
        }
    #endif
}

// MARK: - UpDownButtons

public struct UpDownButtons: View {
    // MARK: Lifecycle

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

    // MARK: Public

    public enum ButtonDirection {
        case down
        case up
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color ?? colors.accent)
                .frame(width: size, height: size * 2, alignment: .center)
            VStack {
                Button(
                    action: { onPress?(.up) },
                    label: { Image(systemName: "plus").font(.system(size: size / 3, weight: .black)) }
                )
                .buttonStyle(FlatButton(
                    color: color ?? colors.accent,
                    textColor: textColor,
                    width: size,
                    height: size,
                    radius: radius
                ))
                Button(
                    action: { onPress?(.down) },
                    label: { Image(systemName: "minus").font(.system(size: size / 3, weight: .black)) }
                )
                .buttonStyle(FlatButton(
                    color: color ?? colors.accent,
                    textColor: textColor,
                    width: size,
                    height: size,
                    radius: radius
                ))
            }
        }
    }

    // MARK: Internal

    @Environment(\.colors) var colors

    @State var radius: CGFloat = 24
    @State var size: CGFloat = 80
    @State var color: Color? = nil
    @State var textColor: Color = .black
    @State var onPress: ((ButtonDirection) -> Void)? = nil
}
