import SwiftUI

/// Pill-shaped HTTP method badge with per-method color coding.
struct MethodBadge: View {

    let method: String

    private var color: Color { .methodColor(for: method) }

    var body: some View {
        Text(method)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
