import SwiftUI

/// Pill-shaped HTTP status code badge with semantic color.
struct StatusBadge: View {

    let code: Int?
    let status: NetworkEntryStatus

    var body: some View {
        Group {
            if let code {
                badge(text: String(code), color: .statusColor(for: code))
            } else {
                switch status {
                case .pending, .inProgress:
                    badge(text: "···", color: .lpFog)
                case .failed:
                    badge(text: "ERR", color: .lpDanger)
                case .cancelled:
                    badge(text: "CXL", color: .lpWarning)
                case .completed:
                    badge(text: "—", color: .lpFog)
                }
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: Capsule())
    }
}
