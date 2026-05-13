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
                        .foregroundStyle(Color.mfStatusColor(code))
                        .frame(width: 36, alignment: .leading)
                } else {
                    Text(entry.status == .failed ? "ERR" : "—")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(entry.status == .failed ? Color.mfDanger : Color.mfFog)
                        .frame(width: 36, alignment: .leading)
                }
            }

            // Path + host
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.mfWarning)
                    }
                    Text(entry.path)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.mfInk)
                        .lineLimit(1)
                }
                Text(entry.host)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.mfFog)
                    .lineLimit(1)
            }

            Spacer()

            // Right side: size + duration
            VStack(alignment: .trailing, spacing: 2) {
                if entry.responseSize > 0 {
                    Text(entry.responseSize.macFormattedSize)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.mfFog)
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
        .mfMethodColor(entry.method)
    }

    private var durationColor: Color {
        guard let d = entry.timing.totalDuration else { return .mfFog }
        if d < 0.3 { return .mfSuccess }
        if d < 1.0 { return .mfWarning }
        return .mfDanger
    }
}
