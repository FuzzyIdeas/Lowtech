import Defaults
import Lowtech
import Sparkle
import SwiftUI

// MARK: - VersionView

public struct VersionView: View {
    // MARK: Lifecycle

    public init(updater: SPUUpdater) {
        self.updater = updater
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Version:")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Text(Bundle.main.version)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Spacer()

                Button("Check for updates") { updater.checkForUpdates() }
                    .buttonStyle(FlatButton())
                    .font(.system(size: 11, weight: .semibold))
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

    // MARK: Internal

    @Default(.checkForUpdates) var checkForUpdates
    @Default(.updateCheckInterval) var updateCheckInterval

    @ObservedObject var updater: SPUUpdater
    @Environment(\.colors) var colors
}

extension Bundle {
    var version: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "1.0.0"
    }
}

// MARK: - SPUUpdater + ObservableObject

extension SPUUpdater: ObservableObject {}
