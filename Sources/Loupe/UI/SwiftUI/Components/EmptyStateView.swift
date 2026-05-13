import SwiftUI

struct EmptyStateView: View {

    enum Kind {
        case noRequests
        case noResults(query: String)
        case error(message: String)
    }

    let kind: Kind

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.10))
                        .frame(width: 80, height: 80)
                    Image(systemName: iconName)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tfBackground)
    }

    // MARK: Private

    private var iconName: String {
        switch kind {
        case .noRequests: return "antenna.radiowaves.left.and.right"
        case .noResults:  return "magnifyingglass"
        case .error:      return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .noRequests: return .blue
        case .noResults:  return Color(uiColor: .secondaryLabel)
        case .error:      return .tfDanger
        }
    }

    private var title: String {
        switch kind {
        case .noRequests: return "No Requests Yet"
        case .noResults:  return "No Results"
        case .error:      return "Something Went Wrong"
        }
    }

    private var subtitle: String {
        switch kind {
        case .noRequests:
            return "Network requests from your app will appear here automatically.\nShake to open Loupe."
        case .noResults(let q):
            return q.isEmpty
                ? "No requests match your current filters.\nTry clearing them."
                : "No results for \"\(q)\".\nTry a different search or clear your filters."
        case .error(let msg):
            return msg
        }
    }
}
