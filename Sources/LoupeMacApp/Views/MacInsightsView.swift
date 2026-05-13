import SwiftUI

/// Dashboard-style snapshot of all captured entries.
struct MacInsightsView: View {

    @EnvironmentObject private var appState: AppState

    private var entries: [MacNetworkEntry] { appState.entries }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if entries.isEmpty {
                    empty
                } else {
                    statTiles
                    slowestSection
                    failuresSection
                    hostSection
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statTiles: some View {
        let total = entries.count
        let success = entries.filter { ($0.statusCode ?? 0) >= 200 && ($0.statusCode ?? 0) < 300 }.count
        let failed = entries.filter { $0.error != nil || ($0.statusCode ?? 0) >= 400 }.count
        let avgDuration = average(entries.compactMap(\.timing.totalDuration))
        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.responseSize }
        let p95 = percentile(entries.compactMap(\.timing.totalDuration), p: 0.95)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile(label: "Total", value: "\(total)", icon: "tray.full", color: .blue)
            tile(label: "Success",
                 value: total == 0 ? "—" : "\(Int(Double(success) / Double(total) * 100))%",
                 icon: "checkmark.seal", color: .green)
            tile(label: "Failures", value: "\(failed)",
                 sub: total == 0 ? nil : "\(Int(Double(failed) / Double(total) * 100))% of total",
                 icon: "exclamationmark.triangle", color: .red)
            tile(label: "Bandwidth", value: totalBytes.macFormattedSize, icon: "arrow.down.circle", color: .indigo)
            tile(label: "Avg", value: avgDuration.map(formatDuration) ?? "—", icon: "clock", color: .orange)
            tile(label: "p95", value: p95.map(formatDuration) ?? "—", icon: "speedometer", color: .purple)
        }
    }

    private func tile(label: String, value: String, sub: String? = nil, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(color)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
            }
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            if let sub { Text(sub).font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var slowestSection: some View {
        let top = entries
            .filter { $0.timing.totalDuration != nil }
            .sorted { ($0.timing.totalDuration ?? 0) > ($1.timing.totalDuration ?? 0) }
            .prefix(5)
        return listSection(title: "Slowest 5", entries: Array(top)) { entry in
            Text(formatDuration(entry.timing.totalDuration ?? 0))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.red)
        }
    }

    private var failuresSection: some View {
        let failures = entries.filter { $0.error != nil || ($0.statusCode ?? 0) >= 400 }
        guard !failures.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            listSection(title: "Recent Failures", entries: Array(failures.prefix(5))) { entry in
                Text(entry.statusCode.map(String.init) ?? "—")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.red)
            }
        )
    }

    private var hostSection: some View {
        var byHost: [String: (count: Int, bytes: Int64, durations: [TimeInterval])] = [:]
        for e in entries {
            var bucket = byHost[e.host, default: (0, 0, [])]
            bucket.count += 1
            bucket.bytes += e.responseSize
            if let d = e.timing.totalDuration { bucket.durations.append(d) }
            byHost[e.host] = bucket
        }
        let rows = byHost.sorted { $0.value.count > $1.value.count }.prefix(5)
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Top Hosts")
            VStack(spacing: 0) {
                ForEach(Array(rows), id: \.key) { host, stats in
                    HStack(spacing: 10) {
                        Image(systemName: "globe").font(.caption).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.isEmpty ? "—" : host)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text("\(stats.count) requests").font(.caption2).foregroundStyle(.tertiary)
                                Text(stats.bytes.macFormattedSize).font(.caption2).foregroundStyle(.tertiary)
                                if let avg = average(stats.durations) {
                                    Text("avg \(formatDuration(avg))").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    if host != rows.last?.key {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func listSection(
        title: String,
        entries: [MacNetworkEntry],
        @ViewBuilder trailing: @escaping (MacNetworkEntry) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        Text(entry.method)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(methodColor(entry.method), in: Capsule())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.url.path.isEmpty ? "/" : entry.url.path)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(entry.host).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        Spacer()
                        trailing(entry)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    if entry.id != entries.last?.id { Divider().padding(.leading, 12) }
                }
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("No requests yet").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func methodColor(_ m: String) -> Color {
        switch m {
        case "GET": return .blue;  case "POST": return .green;  case "PUT": return .orange
        case "PATCH": return .purple;  case "DELETE": return .red;  default: return .gray
        }
    }
    private func formatDuration(_ t: TimeInterval) -> String {
        t < 1 ? String(format: "%.0fms", t * 1000) : String(format: "%.2fs", t)
    }
    private func average(_ vs: [TimeInterval]) -> TimeInterval? {
        vs.isEmpty ? nil : vs.reduce(0, +) / Double(vs.count)
    }
    private func percentile(_ vs: [TimeInterval], p: Double) -> TimeInterval? {
        guard !vs.isEmpty else { return nil }
        let sorted = vs.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))]
    }
}
