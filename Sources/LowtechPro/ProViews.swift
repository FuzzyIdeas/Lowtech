import Defaults
import Lowtech
import LowtechIndie
import Paddle
import Sparkle
import SwiftUI

// MARK: - LicenseRow

/// LunarPro-style license status row: a seal glyph colored by state, the "<App> Pro" name,
/// a human status string, then a borderedProminent "Buy" (trial / inactive only) and a
/// bordered "Activate" / "Manage" button. Bound to a `LowtechPro` instance.
public struct LicenseRow: View {
    public init(pro: LowtechPro, appName: String? = nil) {
        self.pro = pro
        self.appName = appName
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: licenseSeal)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(licenseColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(resolvedAppName) Pro")
                    .font(.system(size: 14, weight: .semibold))
                Text(licenseStatus)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if pro.onTrial || !pro.active {
                Button("Buy") { pro.showCheckout() }
                    .buttonStyle(.borderedProminent)
            }
            Button(licensed ? "Manage" : "Activate") {
                if licensed {
                    pro.manageLicence()
                } else {
                    pro.showLicenseActivation()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    @ObservedObject var pro: LowtechPro

    private let appName: String?

    private var resolvedAppName: String {
        appName ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Pro"
    }

    /// Fully licensed on this Mac (activated and not in trial).
    private var licensed: Bool { pro.productActivated && !pro.onTrial }

    private var licenseSeal: String {
        if licensed { return "checkmark.seal.fill" }
        return pro.onTrial ? "checkmark.seal" : "seal"
    }

    private var licenseColor: Color {
        if licensed { return .lightGreen }
        return pro.onTrial ? .peach : Color(.tertiaryLabelColor)
    }

    private var licenseStatus: String {
        if pro.onTrial {
            if let days = product?.trialDaysRemaining?.intValue, days > 0 {
                return "Trial, \(days) day\(days == 1 ? "" : "s") remaining"
            }
            return "Trial"
        }
        return pro.productActivated ? "Licensed on this Mac" : "Not activated"
    }
}

// MARK: - LicenseAndUpdatesView

/// LunarPro-style combined License + Updates section: the `LicenseRow` followed by the
/// LowtechIndie `UpdatesView`. License state comes from the `LowtechPro` object, updates
/// come from Sparkle and `Defaults[.updateChannel]`.
public struct LicenseAndUpdatesView: View {
    public init(pro: LowtechPro, updater: SPUUpdater, appName: String? = nil, showChannel: Bool = true) {
        self.pro = pro
        self.updater = updater
        self.appName = appName
        self.showChannel = showChannel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LicenseRow(pro: pro, appName: appName)
            Divider()
            UpdatesView(updater: updater, showChannel: showChannel)
        }
    }

    @ObservedObject var pro: LowtechPro

    private let updater: SPUUpdater
    private let appName: String?
    private let showChannel: Bool
}

// MARK: - AboutView

/// rcmd-style About pane: app icon, name, version, a Pro / Trial pill driven by `LowtechPro`,
/// Website / Contact / Discord links, and a copyright line. The links are plain params so the
/// view stays backend-light.
public struct AboutView: View {
    public init(
        appName: String,
        pro: LowtechPro? = nil,
        updater: SPUUpdater? = nil,
        websiteURL: URL? = nil,
        contactURL: URL? = nil,
        discordURL: URL? = nil,
        vendorName: String = "The low-tech guys"
    ) {
        self.appName = appName
        self.pro = pro
        self.updater = updater
        self.websiteURL = websiteURL
        self.contactURL = contactURL
        self.discordURL = discordURL
        self.vendorName = vendorName
    }

    public var body: some View {
        VStack(spacing: 14) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 128, height: 128)
            }
            Text(appName)
                .round(48, weight: .black)
                .padding(.top, -4)
            Text("v\(Bundle.main.version)")
                .mono(13, weight: .regular)
                .foregroundColor(.secondary)

            if let updater {
                GentleUpdateView(updater: updater)
            }

            if let pro {
                if pro.onTrial {
                    let days = (product?.trialDaysRemaining ?? 0).intValue
                    Text("Trial (\(days) day\(days == 1 ? "" : "s") left)")
                        .mono(11, weight: .semibold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                        .foregroundColor(.orange)
                } else if pro.active {
                    Text("Pro")
                        .mono(11, weight: .semibold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.18)))
                        .foregroundColor(.red)
                }
            }

            if websiteURL != nil || contactURL != nil || discordURL != nil {
                HStack(spacing: 20) {
                    if let websiteURL { Link("Website", destination: websiteURL) }
                    if let contactURL { Link("Contact", destination: contactURL) }
                    if let discordURL { Link("Get help on Discord", destination: discordURL) }
                }
                .underline()
                .opacity(0.75)
                .padding(.top, 6)
            }

            Text("Made by \"\(vendorName)\"")
                .round(11)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Text("© \(String(Calendar.current.component(.year, from: Date()))) THE LOW TECH GUYS")
                .round(10)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ObservedObject private var um = UM

    private let appName: String
    private let pro: LowtechPro?
    private let updater: SPUUpdater?
    private let websiteURL: URL?
    private let contactURL: URL?
    private let discordURL: URL?
    private let vendorName: String
}

// MARK: - LicenseView

public struct LicenseView: View {
    public init(pro: LowtechPro) {
        self.pro = pro
    }

    public var body: some View {
        HStack {
            Text("Licence:")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            Text(pro.onTrial ? "trial" : (pro.productActivated ? "active" : "inactive"))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Spacer()

            if pro.onTrial {
                Button("Buy") { pro.showCheckout() }
                    .buttonStyle(FlatButton())
                    .font(.system(size: 12, weight: .semibold))
            }
            Button((pro.productActivated && !pro.onTrial) ? "Manage" : "Activate") { pro.showLicenseActivation() }
                .buttonStyle(FlatButton())
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.1)))
        .padding(.top, 10)
    }

    @ObservedObject var pro: LowtechPro
}
