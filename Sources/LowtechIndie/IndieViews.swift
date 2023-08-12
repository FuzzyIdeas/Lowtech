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
        VStack(alignment: .leading) {
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
                .buttonStyle(PickerButton(horizontalPadding: 6, verticalPadding: 3, enumValue: $updateCheckInterval, onValue: 0))
                .font(.system(size: 11, weight: .semibold))
                Button("Daily") {
                    checkForUpdates = true
                    updateCheckInterval = UpdateCheckInterval.daily.rawValue
                }
                .buttonStyle(PickerButton(
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    enumValue: $updateCheckInterval,
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
                    enumValue: $updateCheckInterval,
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

    @Default(.checkForUpdates) var checkForUpdates
    @Default(.updateCheckInterval) var updateCheckInterval

    @ObservedObject var updater: SPUUpdater
}

public extension Bundle {
    var version: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

// MARK: - SPUUpdater + ObservableObject

public extension SPUUpdater: ObservableObject {}
