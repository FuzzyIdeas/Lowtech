import DynamicColor
import SwiftUI
import SystemColors

#if canImport(AppKit)
    import AppKit
#endif

#if canImport(UIKit)
    import UIKit
#endif

public extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
            self.init(light: UIColor(light), dark: UIColor(dark))
        #else
            self.init(light: NSColor(light), dark: NSColor(dark))
        #endif
    }

    #if canImport(UIKit)
        init(light: UIColor, dark: UIColor) {
            #if os(watchOS)
                // watchOS does not support light mode / dark mode
                // Per Apple HIG, prefer dark-style interfaces
                self.init(uiColor: dark)
            #else
                self.init(uiColor: UIColor(dynamicProvider: { traits in
                    switch traits.userInterfaceStyle {
                    case .light, .unspecified:
                        return light

                    case .dark:
                        return dark

                    @unknown default:
                        assertionFailure("Unknown userInterfaceStyle: \(traits.userInterfaceStyle)")
                        return light
                    }
                }))
            #endif
        }
    #endif

    #if canImport(AppKit)
        init(light: NSColor, dark: NSColor) {
            self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                switch appearance.name {
                case .aqua,
                     .vibrantLight,
                     .accessibilityHighContrastAqua,
                     .accessibilityHighContrastVibrantLight:
                    return light

                case .darkAqua,
                     .vibrantDark,
                     .accessibilityHighContrastDarkAqua,
                     .accessibilityHighContrastVibrantDark:
                    return dark

                default:
                    assertionFailure("Unknown appearance: \(appearance.name)")
                    return light
                }
            }))
        }
    #endif
}

// MARK: - FG

public struct FG {
    var gray = Color(light: Color.lightGray, dark: Color.darkGray)
    var primary = Color(light: Color.black, dark: Color.white)
}

// MARK: - BG

public struct BG {
    var gray = Color(light: Color.darkGray, dark: Color.lightGray)
    var primary = Color(light: Color.white, dark: Color.black)
}

public extension Color {
    var isLight: Bool {
        let components = ns.toRGBAComponents()
        let brightness = ((components.r * 299.0) + (components.g * 587.0) + (components.b * 114.0)) / 1000.0

        return brightness >= 0.4
    }

    func textColor() -> Color {
        isLight ? .black : .white
    }

    static let darkGray = Color(hue: 0, saturation: 0.01, brightness: 0.32)
    static let blackGray = Color(hue: 0.03, saturation: 0.12, brightness: 0.18)
    static let lightGray = Color(hue: 0, saturation: 0.0, brightness: 0.92)

    static let hotRed = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    static let lightGold = Color(hue: 0.09, saturation: 0.28, brightness: 0.94)

    static let blackTurqoise = Color(hex: 0x1D2E32)
    static let burntSienna = Color(hex: 0xE48659)
    static let scarlet = Color(hue: 0.98, saturation: 0.82, brightness: 1.00)
    static let saffron = Color(hue: 0.11, saturation: 0.82, brightness: 1.00)

    static let lightMauve = Color(hue: 0.95, saturation: 0.39, brightness: 0.93)
    static let grayMauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.43)
    static let mauve = Color(hue: 252 / 360, saturation: 0.29, brightness: 0.23)
    static let pinkMauve = Color(hue: 0.95, saturation: 0.76, brightness: 0.42)
    static let blackMauve = Color(hue: 252 / 360, saturation: 0.08, brightness: 0.12)
    static let golden = Color(hue: 39 / 360, saturation: 1.0, brightness: 0.64)
    static let lunarYellow = Color(hue: 0.11, saturation: 0.47, brightness: 1.00)
    static let sunYellow = Color(hue: 0.1, saturation: 0.57, brightness: 1.00)
    static let peach = Color(hue: 0.08, saturation: 0.42, brightness: 1.00)
    static let calmBlue = Color(hue: 214 / 360, saturation: 0.7, brightness: 0.84)
    static let calmGreen = Color(hue: 0.36, saturation: 0.80, brightness: 0.78)
    static let lightGreen = Color(hue: 141 / 360, saturation: 0.50, brightness: 0.83)

    static let xdr = Color(hue: 0.61, saturation: 0.26, brightness: 0.78)
    static let subzero = Color(hue: 0.98, saturation: 0.56, brightness: 1.00)

    static var accent = Color.peach

    static let bg = BG()
    static let fg = FG()

    static let inverted = Color(light: Color.white, dark: Color.black)
    static let highContrast = Color(light: Color.black, dark: Color.white)
    static let invertedGray = Color(light: Color.lightGray, dark: Color.darkGray)
    static let dynamicGray = Color(light: Color.darkGray, dark: Color.lightGray)
    static let mauvish = Color(light: Color.pinkMauve, dark: Color.lightMauve)
}
