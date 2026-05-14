import SwiftUI

/// Waterfall timing breakdown powered by `URLSessionTaskMetrics`.
struct RequestTimelineView: View {

    let entry: NetworkEntry

    private struct Phase: Identifiable {
        let id = UUID()
        let label: String
        let color: Color
        let offset: TimeInterval
        let duration: TimeInterval
    }

    private var phases: [Phase] {
        guard let detail = entry.timingDetail,
              let base = detail.absoluteStart else { return [] }

        var result: [Phase] = []

        func phase(_ label: String, _ color: Color, _ start: Date?, _ end: Date?) {
            guard let s = start, let e = end, e > s else { return }
            result.append(Phase(label: label, color: color,
                                offset: s.timeIntervalSince(base),
                                duration: e.timeIntervalSince(s)))
        }

        phase("DNS Lookup",    .purple, detail.dnsStart,      detail.dnsEnd)
        phase("TCP Connect",   .blue,   detail.connectStart,  detail.connectEnd)
        phase("TLS Handshake", .orange, detail.tlsStart,      detail.tlsEnd)
        phase("Request Sent",  .green,  detail.requestStart,  detail.requestEnd)
        phase("Response",      .teal,   detail.responseStart, detail.responseEnd)
        return result
    }

    private var totalDuration: TimeInterval {
        entry.timingDetail?.totalDuration ?? entry.timing.totalDuration ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                if phases.isEmpty {
                    waitingCard
                } else {
                    waterfallCard
                    timestampsCard
                }
            }
            .padding()
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Duration")
                    .font(.caption).foregroundStyle(.secondary)
                Text(entry.timing.formattedDuration)
                    .font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Started").font(.caption).foregroundStyle(.secondary)
                Text(entry.timing.startDate, style: .time)
                    .font(.callout.monospacedDigit())
            }
        }
        .padding()
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Waterfall

    private var waterfallCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Waterfall").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            ForEach(phases) { phase in
                waterfallBar(phase: phase)
            }

            Divider()
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(format(totalDuration))
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding()
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func waterfallBar(phase: Phase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(phase.color).frame(width: 8, height: 8)
                Text(phase.label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(format(phase.duration))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let off  = totalDuration > 0 ? CGFloat(phase.offset   / totalDuration) : 0
                let size = totalDuration > 0 ? CGFloat(phase.duration / totalDuration) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(phase.color.opacity(0.10))
                    Capsule().fill(phase.color)
                        .frame(width: max(4, w * size))
                        .offset(x: w * off)
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - Waiting state

    private var waitingCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("Detailed timing will appear here once the request completes.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timestamps

    private var timestampsCard: some View {
        guard let detail = entry.timingDetail,
              let base = detail.absoluteStart else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("Timestamps").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                tsRow("Request Started", date: base, base: base)
                if let d = detail.dnsEnd       { tsRow("DNS Done",       date: d, base: base) }
                if let d = detail.connectEnd   { tsRow("TCP Connected",  date: d, base: base) }
                if let d = detail.tlsEnd       { tsRow("TLS Done",       date: d, base: base) }
                if let d = detail.requestEnd   { tsRow("Request Sent",   date: d, base: base) }
                if let d = detail.responseEnd  { tsRow("Response Done",  date: d, base: base) }
            }
            .padding()
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
        )
    }

    private func tsRow(_ label: String, date: Date, base: Date) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(date, style: .time).font(.subheadline.monospacedDigit())
                Text("+\(format(date.timeIntervalSince(base)))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        t < 1 ? String(format: "%.0f ms", t * 1000) : String(format: "%.2f s", t)
    }
}
