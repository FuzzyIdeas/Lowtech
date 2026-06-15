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
            Button("v\(version) available") { updater.checkForUpdates() }
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
            Button("Check for updates") { updater.checkForUpdates() }
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
                Text("Version:")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Text(Bundle.main.version)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Spacer()

                GentleUpdateView(updater: updater)
            }
            HStack(spacing: 3) {
                Text("Check automatically")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Spacer()

                Button("Never") {
                    checkForUpdates = false
                    updateCheckInterval = 0
                }
                .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: updateCheckInterval, onValue: 0))
                .font(.system(size: 11, weight: .semibold))
                Button("Daily") {
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
                Button("Weekly") {
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
    public init(updater: SPUUpdater, showChannel: Bool = true) {
        self.updater = updater
        self.showChannel = showChannel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("Version") {
                HStack(spacing: 8) {
                    Text(Bundle.main.version)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(.quaternary))
                        .foregroundStyle(.secondary)
                    Button("Check for Updates") { updater.checkForUpdates() }
                        .buttonStyle(.bordered)
                }
            }

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
                        Text("every").foregroundStyle(.secondary)
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
            }

            if showChannel {
                row("Update channel") {
                    Picker("", selection: $updateChannel) {
                        Text("Release").tag(UpdateChannel.release)
                        Text("Beta").tag(UpdateChannel.beta)
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

    private let showChannel: Bool

    @Default(.checkForUpdates) var checkForUpdates
    @Default(.silentUpdates) var silentUpdates
    @Default(.updateCheckInterval) var updateCheckInterval
    @Default(.updateChannel) var updateChannel
}

// MARK: - SPUUpdater + ObservableObject

extension SPUUpdater: @retroactive ObservableObject {}
