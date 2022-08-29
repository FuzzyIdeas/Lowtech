import Defaults
import Lowtech
import SwiftUI

// MARK: - LicenseView

public struct LicenseView: View {
    // MARK: Lifecycle

    public init(pro: LowtechPro) {
        self.pro = pro
    }

    // MARK: Public

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

    // MARK: Internal

    @ObservedObject var pro: LowtechPro
    @Environment(\.colors) var colors
}
