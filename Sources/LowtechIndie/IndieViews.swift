import Defaults
import Lowtech
import Sparkle
import SwiftUI

// MARK: - GentleUpdateView

public struct GentleUpdateView: View {
    public init(updater: SPUUpdater) {
        self.updater = updater
    }

    public var body: some View {
        if let version = um.newVersion {
            Button(String(localized: "v\(version) available", table: "Lowtech", comment: "Button shown when an update is available. The placeholder is the new version number.")) { updater.checkForUpdates() }
                .buttonStyle(FlatButton(
                    color: .orange,
                    textColor: Color.blackMauve,
                    horizontalPadding: 6,
                    verticalPadding: 3
                ))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(.leastNonzeroMagnitude)
                .scaledToFit()
        } else {
            Button(String(localized: "Check for updates", table: "Lowtech")) { updater.checkForUpdates() }
                .buttonStyle(FlatButton())
                .font(.system(size: 11, weight: .semibold))
        }
    }

    @ObservedObject var um = UM
    @ObservedObject var updater: SPUUpdater
}

// MARK: - VersionView

public struct VersionView: View {
    public init(updater: SPUUpdater) {
        self.updater = updater
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Version:", tableName: "Lowtech")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Text(Bundle.main.version)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Spacer()

                GentleUpdateView(updater: updater)
            }
            HStack(spacing: 3) {
                Text("Check automatically", tableName: "Lowtech")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Spacer()

                Button(String(localized: "Never", table: "Lowtech")) {
                    checkForUpdates = false
                    updateCheckInterval = 0
                }
                .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: updateCheckInterval, onValue: 0))
                .font(.system(size: 11, weight: .semibold))
                Button(String(localized: "Daily", table: "Lowtech")) {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.daily.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: updateCheckInterval,
                    onValue: UpdateCheckInterval.daily.rawValue
                ))
                .font(.system(size: 11, weight: .semibold))
                Button(String(localized: "Weekly", table: "Lowtech")) {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.weekly.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: updateCheckInterval,
                    onValue: UpdateCheckInterval.weekly.rawValue
                ))
                .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.1)))
        .padding(.top, 10)
    }

    @ObservedObject var updater: SPUUpdater

    @Default(.checkForUpdates) var checkForUpdates
    @Default(.updateCheckInterval) var updateCheckInterval

}

// MARK: - AutoUpdate

private enum AutoUpdate {
    case off
    case notify
    case install
}

// MARK: - UpdatesView

/// LunarPro-style Updates section.
///
/// - A *Version* row: a monospaced version pill plus a bordered "Check for Updates" button.
/// - An *Automatic updates* row: a single Off / Check and notify / Install silently picker
///   followed by an "every [day / 3 days / week]" picker that dims when updates are off.
/// - An *Update channel* row: a segmented Release / Beta selector bound to `Defaults[.updateChannel]`.
///
/// Everything is driven by Sparkle's native default keys (`SUEnableAutomaticChecks`,
/// `SUAutomaticallyUpdate`, `SUScheduledCheckInterval`) plus `Defaults[.updateChannel]`,
/// so it needs nothing from the app beyond the `SPUUpdater`.
public struct UpdatesView: View {
    public init(updater: SPUUpdater, showChannel: Bool = true, changelogURL: URL? = nil) {
        self.updater = updater
        self.showChannel = showChannel
        self.changelogURL = changelogURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(String(localized: "Version", table: "Lowtech")) {
                HStack(spacing: 8) {
                    if let changelogURL {
                        Button { openURL(changelogURL) } label: { versionCapsule }
                            .buttonStyle(.plain)
                            .help(Text("View the changelog", tableName: "Lowtech"))
                    } else {
                        versionCapsule
                    }
                    Button(String(localized: "Check for Updates", table: "Lowtech")) { updater.checkForUpdates() }
                        .buttonStyle(.bordered)
                }
            }

            row(String(localized: "Automatic updates", table: "Lowtech")) {
                HStack(spacing: 6) {
                    Picker(String(localized: "Automatic updates", table: "Lowtech"), selection: autoUpdate) {
                        Text("Off", tableName: "Lowtech").tag(AutoUpdate.off)
                        Text("Check and notify", tableName: "Lowtech").tag(AutoUpdate.notify)
                        Text("Install silently", tableName: "Lowtech").tag(AutoUpdate.install)
                    }
                    .labelsHidden()
                    .fixedSize()

                    HStack(spacing: 6) {
                        Text("every", tableName: "Lowtech", comment: "Before the update check interval picker: every day, 3 days or week").foregroundStyle(.secondary).fixedSize()
                        Picker(String(localized: "Check interval", table: "Lowtech"), selection: $updateCheckInterval) {
                            Text("day", tableName: "Lowtech", comment: "Update check interval, after \"every\"").tag(UpdateCheckInterval.daily.rawValue)
                            Text("3 days", tableName: "Lowtech", comment: "Update check interval, after \"every\"").tag(UpdateCheckInterval.everyThreeDays.rawValue)
                            Text("week", tableName: "Lowtech", comment: "Update check interval, after \"every\"").tag(UpdateCheckInterval.weekly.rawValue)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .opacity(checkForUpdates ? 1 : 0.4)
                    .disabled(!checkForUpdates)
                }
            }

            if showChannel {
                row(String(localized: "Update channel", table: "Lowtech")) {
                    Picker(String(localized: "Update channel", table: "Lowtech"), selection: $updateChannel) {
                        Text("Release", tableName: "Lowtech", comment: "Update channel for stable versions").tag(UpdateChannel.release)
                        Text("Beta", tableName: "Lowtech", comment: "Update channel for test versions").tag(UpdateChannel.beta)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            if um.newVersion != nil {
                GentleUpdateView(updater: updater)
            }
        }
    }

    @ViewBuilder
    private func row(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
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

    @ObservedObject var um = UM
    @ObservedObject var updater: SPUUpdater
    @Environment(\.openURL) private var openURL

    private let showChannel: Bool
    private let changelogURL: URL?

    @Default(.checkForUpdates) var checkForUpdates
    @Default(.silentUpdates) var silentUpdates
    @Default(.updateCheckInterval) var updateCheckInterval
    @Default(.updateChannel) var updateChannel

    private var versionCapsule: some View {
        Text(Bundle.main.version)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(.quaternary))
            .foregroundStyle(.secondary)
    }
}

// MARK: - SPUUpdater + ObservableObject

extension SPUUpdater: @retroactive ObservableObject {}
