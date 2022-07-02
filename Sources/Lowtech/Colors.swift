import DynamicColor
import SwiftUI
import SystemColors

// MARK: - Colors

public struct Colors {
    // MARK: Lifecycle

    public init(_ colorScheme: SwiftUI.ColorScheme = .light, accent: Color) {
        self.accent = accent
        self.colorScheme = colorScheme
        bg = BG(colorScheme: colorScheme)
        fg = FG(colorScheme: colorScheme)
    }

    // MARK: Public

    public struct FG {
        // MARK: Public

        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        // MARK: Internal

        var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
        var primary: Color { isDark ? .white : .black }
    }

    public struct BG {
        // MARK: Public

        public var colorScheme: SwiftUI.ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        // MARK: Internal

        var gray: Color { isDark ? Colors.darkGray : Colors.lightGray }
        var primary: Color { isDark ? .black : .white }
    }

    public static var light = Colors(.light, accent: Colors.lunarYellow)
    public static var dark = Colors(.dark, accent: Colors.peach)

    public static let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
    public static let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
    public static let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)

    public static let red = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    public static let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)

    public static let blackTurqoise = Color(hex: 0x1D2E32)
    public static let burntSienna = Color(hex: 0xE48659)
    public static let scarlet = Color(NSColor(hue: 0.98, saturation: 0.82, brightness: 1.00, alpha: 1.00))
    public static let saffron = Color(NSColor(hue: 0.11, saturation: 0.82, brightness: 1.00, alpha: 1.00))

    public static let grayMauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.43)
    public static let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
    public static let pinkMauve = Color(hue: 0.95, saturation: 0.76, brightness: 0.42)
    public static let blackMauve = Color(
        hue: 252 / 360,
        saturation: 0.08,
        brightness:
        0.12
    )
    public static let yellow = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
    public static let lunarYellow = Color(hue: 0.11, saturation: 0.47, brightness: 1.00)
    public static let sunYellow = Color(hue: 0.1, saturation: 0.57, brightness: 1.00)
    public static let peach = Color(hue: 0.08, saturation: 0.42, brightness: 1.00)
    public static let blue = Color(hue: 214 / 360, saturation: 1.0, brightness: 0.54)
    public static let green = Color(hue: 0.36, saturation: 0.80, brightness: 0.78)
    public static let lightGreen = Color(hue: 141 / 360, saturation: 0.50, brightness: 0.83)

    public static let xdr = Color(hue: 0.61, saturation: 0.26, brightness: 0.78)
    public static let subzero = Color(hue: 0.98, saturation: 0.56, brightness: 1.00)

    public var accent: Color
    public var colorScheme: SwiftUI.ColorScheme

    public var bg: BG
    public var fg: FG

    public var isDark: Bool { colorScheme == .dark }
    public var isLight: Bool { colorScheme == .light }
    public var inverted: Color { isDark ? .black : .white }
    public var invertedGray: Color { isDark ? Colors.darkGray : Colors.lightGray }
    public var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
}

// MARK: - ColorsKey

private struct ColorsKey: EnvironmentKey {
    public static let defaultValue = Colors.light
}

public extension EnvironmentValues {
    var colors: Colors {
        get { self[ColorsKey.self] }
        set { self[ColorsKey.self] = newValue }
    }
}

public extension View {
    func colors(_ colors: Colors) -> some View {
        environment(\.colors, colors)
    }
}

public extension Color {
    var textColor: Color {
        NSColor(self).isLight() ? .black : .white
    }
}
