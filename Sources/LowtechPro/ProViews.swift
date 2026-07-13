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
    public init(pro: LowtechPro, updater: SPUUpdater, appName: String? = nil, showChannel: Bool = true, changelogURL: URL? = nil) {
        self.pro = pro
        self.updater = updater
        self.appName = appName
        self.showChannel = showChannel
        self.changelogURL = changelogURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LicenseRow(pro: pro, appName: appName)
            Divider()
            UpdatesView(updater: updater, showChannel: showChannel, changelogURL: changelogURL)
        }
    }

    @ObservedObject var pro: LowtechPro

    private let updater: SPUUpdater
    private let appName: String?
    private let showChannel: Bool
    private let changelogURL: URL?
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
        sourceURL: URL? = nil,
        changelogURL: URL? = nil,
        vendorName: String = "The low-tech guys"
    ) {
        self.appName = appName
        self.pro = pro
        self.updater = updater
        self.websiteURL = websiteURL
        self.contactURL = contactURL
        self.discordURL = discordURL
        self.sourceURL = sourceURL
        self.changelogURL = changelogURL
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
            Group {
                if let changelogURL {
                    Button { openURL(changelogURL) } label: {
                        Text("v\(Bundle.main.version)").mono(13, weight: .regular)
                    }
                    .buttonStyle(.plain)
                    .help("View the changelog")
                } else {
                    Text("v\(Bundle.main.version)").mono(13, weight: .regular)
                }
            }
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

            if websiteURL != nil || contactURL != nil || discordURL != nil || sourceURL != nil || changelogURL != nil {
                HStack(spacing: 20) {
                    if let websiteURL { Link("Website", destination: websiteURL) }
                    if let contactURL { Link("Contact", destination: contactURL) }
                    if let discordURL { Link("Discord", destination: discordURL) }
                    if let sourceURL { Link("Source", destination: sourceURL) }
                    if let changelogURL { Link("Changelog", destination: changelogURL) }
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
    @Environment(\.openURL) private var openURL

    private let appName: String
    private let pro: LowtechPro?
    private let updater: SPUUpdater?
    private let websiteURL: URL?
    private let contactURL: URL?
    private let discordURL: URL?
    private let sourceURL: URL?
    private let changelogURL: URL?
    private let vendorName: String
}

// MARK: - AppInfoPopoverView

/// Reusable menubar "App Info" popover, styled like a grouped Settings Form: an
/// identity header (icon + name + version), then Licence / Updates / Links as
/// rounded cards over an opaque fill.
///
/// `trailing` adds an app-specific control to the Links card (e.g. a "Show
/// tutorial" button); it receives a `dismiss` closure so that control can close
/// the popover. All URLs are optional, so a link only renders when provided.
public struct AppInfoPopoverView<Trailing: View>: View {
    public init(
        appName: String,
        pro: LowtechPro? = nil,
        updater: SPUUpdater? = nil,
        websiteURL: URL? = nil,
        contactURL: URL? = nil,
        discordURL: URL? = nil,
        sourceURL: URL? = nil,
        changelogURL: URL? = nil,
        width: CGFloat = 460,
        @ViewBuilder trailing: @escaping (@escaping () -> Void) -> Trailing = { _ in EmptyView() }
    ) {
        self.appName = appName
        self.pro = pro
        self.updater = updater
        self.websiteURL = websiteURL
        self.contactURL = contactURL
        self.discordURL = discordURL
        self.sourceURL = sourceURL
        self.changelogURL = changelogURL
        self.width = width
        self.trailing = trailing
    }

    public var body: some View {
        ZStack {
            // The system popover chrome is translucent enough that the desktop
            // behind the window washes out the text. Scaling the fill up bleeds
            // it past the content into the popover's edges and arrow, which a
            // plain .background() would leave glassy (same trick as PaddedPopoverView).
            Color.inverted.opacity(0.75).scaleEffect(1.5)

            VStack(alignment: .leading, spacing: 14) {
                identity

                if let pro {
                    InfoCard("Licence") {
                        LicenseRow(pro: pro, appName: appName)
                    }
                }

                if let updater {
                    InfoCard("Updates") {
                        updates(updater)
                    }
                }

                InfoCard("Links") {
                    links
                }
            }
            .padding(16)
            .frame(width: width)
        }
        .fixedSize()
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var um = UM

    @Default(.checkForUpdates) private var checkForUpdates
    @Default(.silentUpdates) private var silentUpdates
    @Default(.updateCheckInterval) private var updateCheckInterval
    @Default(.updateChannel) private var updateChannel

    private let appName: String
    private let pro: LowtechPro?
    private let updater: SPUUpdater?
    private let websiteURL: URL?
    private let contactURL: URL?
    private let discordURL: URL?
    private let sourceURL: URL?
    private let changelogURL: URL?
    private let width: CGFloat
    private let trailing: (@escaping () -> Void) -> Trailing

    private var identity: some View {
        HStack(spacing: 12) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(appName).round(22, weight: .black)
                Text("v\(Bundle.main.version)")
                    .mono(11, weight: .regular)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.leading, 2)
    }

    /// The version is deliberately plain text: the Links card already carries a
    /// Changelog button, so making it a second changelog link only adds a
    /// clickable target that looks like a label.
    @ViewBuilder private func updates(_ updater: SPUUpdater) -> some View {
        row("Automatic updates") {
            HStack(spacing: 6) {
                Picker("", selection: autoUpdate) {
                    Text("Off").tag(AutoUpdate.off)
                    Text("Check and notify").tag(AutoUpdate.notify)
                    Text("Install silently").tag(AutoUpdate.install)
                }
                .labelsHidden()
                .fixedSize()

                HStack(spacing: 6) {
                    Text("every").foregroundStyle(.secondary).fixedSize()
                    Picker("", selection: $updateCheckInterval) {
                        Text("day").tag(UpdateCheckInterval.daily.rawValue)
                        Text("3 days").tag(UpdateCheckInterval.everyThreeDays.rawValue)
                        Text("week").tag(UpdateCheckInterval.weekly.rawValue)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .opacity(checkForUpdates ? 1 : 0.4)
                .disabled(!checkForUpdates)
            }
            // Outside a Form an unstyled Picker defaults to a tall list style.
            .pickerStyle(.menu)
        }

        Divider()

        row("Update channel") {
            Picker("", selection: $updateChannel) {
                Text("Release").tag(UpdateChannel.release)
                Text("Beta").tag(UpdateChannel.beta)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
        }

        Divider()

        row("Check for updates") {
            Button("Check Now") { updater.checkForUpdates() }
                .buttonStyle(.bordered)
        }

        if um.newVersion != nil {
            Divider()
            GentleUpdateView(updater: updater)
        }
    }

    private var links: some View {
        HStack(spacing: 6) {
            linkButton("Website", websiteURL)
            linkButton("Contact", contactURL)
            linkButton("Discord", discordURL)
            linkButton("Source", sourceURL)
            linkButton("Changelog", changelogURL)

            Spacer()

            trailing { dismiss() }
        }
        .font(.system(size: 11, weight: .semibold))
    }

    /// Merges `checkForUpdates` and `silentUpdates` into one Off / Check and notify / Install silently selector.
    private var autoUpdate: Binding<AutoUpdate> {
        Binding(
            get: { checkForUpdates ? (silentUpdates ? .install : .notify) : .off },
            set: { mode in
                checkForUpdates = mode != .off
                if mode != .off {
                    silentUpdates = mode == .install
                }
            }
        )
    }

    @ViewBuilder private func row(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }

    @ViewBuilder private func linkButton(_ title: String, _ url: URL?) -> some View {
        if let url {
            Button(title) { openURL(url) }
                .buttonStyle(FlatButton(color: .primary.opacity(0.1), textColor: .primary, horizontalPadding: 6, verticalPadding: 3))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - AutoUpdate

private enum AutoUpdate {
    case off
    case notify
    case install
}

// MARK: - InfoCard

/// One grouped-Form-style section: a small secondary caption over a rounded card.
///
/// Hand-built rather than `Form { Section }.formStyle(.grouped)` because a grouped
/// Form is List-backed and reports no intrinsic height, leaving an NSPopover with
/// nothing to size itself to. The fill is a scheme-relative solid, never a Material:
/// a Material here would blur the desktop behind the window rather than the card it
/// belongs to, and take on arbitrary colours from it.
private struct InfoCard<Content: View>: View {
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
        }
    }

    private let title: String?
    @ViewBuilder private let content: () -> Content
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
