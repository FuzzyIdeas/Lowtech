import DynamicColor
import SwiftUI
import SystemColors

// MARK: - Colors

public struct Colors {
    // MARK: Lifecycle

    public init(_ colorScheme: ColorScheme = .light, accent: Color) {
        self.accent = accent
        self.colorScheme = colorScheme
        bg = BG(colorScheme: colorScheme)
        fg = FG(colorScheme: colorScheme)
    }

    // MARK: Public

    public struct FG {
        public var colorScheme: ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        public var gray: Color { isDark ? Colors.lightGray : Colors.darkGray }
        public var primary: Color { isDark ? .white : .black }
    }

    public struct BG {
        public var colorScheme: ColorScheme

        public var isDark: Bool { colorScheme == .dark }
        public var isLight: Bool { colorScheme == .light }

        public var gray: Color { isDark ? Colors.darkGray : Colors.lightGray }
        public var primary: Color { isDark ? .black : .white }
    }

    public static var light = Colors(.light, accent: Colors.red)
    public static var dark = Colors(.dark, accent: Colors.red)

    public static let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
    public static let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
    public static let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)

    public static let red = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    public static let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)
    public static let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
    public static let blackMauve = Color(hue: 252 / 360, saturation: 0.08, brightness: 0.12)
    public static let yellow = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
    public static let blue = Color(hue: 214 / 360, saturation: 1.0, brightness: 0.54)
    public static let green = Color(hue: 141 / 360, saturation: 0.59, brightness: 0.58)
    public static let blackTurqoise = Color(hex: 0x1D2E32)
    public static let burntSienna = Color(hex: 0xE48659)

    public var accent: Color
    public var colorScheme: ColorScheme

    public var bg: BG
    public var fg: FG

    public var isDark: Bool { colorScheme == .dark }
    public var isLight: Bool { colorScheme == .light }
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
