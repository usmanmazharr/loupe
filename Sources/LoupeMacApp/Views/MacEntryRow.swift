import SwiftUI

struct MacEntryRow: View {

    let entry: MacNetworkEntry

    var body: some View {
        HStack(spacing: 10) {
            // Method badge — pill, muted accent tint
            Text(entry.method)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(methodColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(methodColor.opacity(0.12), in: Capsule())
                .frame(width: 62, alignment: .center)

            // Status code / spinner
            Group {
                if entry.status == .inProgress {
                    ProgressView().scaleEffect(0.55)
                        .frame(width: 36)
                } else if let code = entry.statusCode {
                    Text(String(code))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.lpStatusColor(code))
                        .frame(width: 36, alignment: .leading)
                } else {
                    Text(entry.status == .failed ? "ERR" : "—")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(entry.status == .failed ? Color.lpDanger : Color.lpFog)
                        .frame(width: 36, alignment: .leading)
                }
            }

            // Path + host
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.lpWarning)
                    }
                    Text(entry.path)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.lpInk)
                        .lineLimit(1)
                }
                Text(entry.host)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.lpFog)
                    .lineLimit(1)
            }

            Spacer()

            // Right side: size + duration
            VStack(alignment: .trailing, spacing: 2) {
                if entry.responseSize > 0 {
                    Text(entry.responseSize.macFormattedSize)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.lpFog)
                }
                Text(entry.timing.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(durationColor)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Colors

    private var methodColor: Color {
        .lpMethodColor(entry.method)
    }

    private var durationColor: Color {
        guard let d = entry.timing.totalDuration else { return .lpFog }
        if d < 0.3 { return .lpSuccess }
        if d < 1.0 { return .lpWarning }
        return .lpDanger
    }
}
