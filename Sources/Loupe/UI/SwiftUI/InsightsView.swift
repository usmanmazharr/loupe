import SwiftUI

/// Quick-glance dashboard summarising the currently filtered entries.
struct InsightsView: View {

    @EnvironmentObject private var viewModel: LoupeViewModel
    @Environment(\.dismiss) private var dismiss

    private var entries: [NetworkEntry] { viewModel.allEntries }

    var body: some View {
        NavigationView {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.lpBackground.ignoresSafeArea())
            .lpNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tiles

    private var statTiles: some View {
        let total = entries.count
        let success = entries.filter { ($0.statusCode ?? 0) >= 200 && ($0.statusCode ?? 0) < 300 }.count
        let failed = entries.filter { $0.error != nil || ($0.statusCode ?? 0) >= 400 }.count
        let avgDuration = average(entries.compactMap(\.timing.totalDuration))
        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.responseSize }
        let p95 = percentile(entries.compactMap(\.timing.totalDuration), p: 0.95)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile(label: "Total", value: "\(total)", icon: "tray.full", color: .blue)
            tile(label: "Success",
                 value: total == 0 ? "—" : "\(Int(Double(success) / Double(total) * 100))%",
                 icon: "checkmark.seal", color: .lpSuccess)
            tile(label: "Failures",
                 value: "\(failed)",
                 sub: total == 0 ? nil : "\(Int(Double(failed) / Double(total) * 100))% of total",
                 icon: "exclamationmark.triangle", color: .lpDanger)
            tile(label: "Bandwidth", value: totalBytes.formattedSize, icon: "arrow.down.circle", color: .indigo)
            tile(label: "Avg",
                 value: avgDuration.map(formatDuration) ?? "—",
                 icon: "clock", color: .lpWarning)
            tile(label: "p95",
                 value: p95.map(formatDuration) ?? "—",
                 icon: "speedometer", color: .purple)
        }
    }

    private func tile(label: String, value: String, sub: String? = nil, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            if let sub {
                Text(sub).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sections

    private var slowestSection: some View {
        let top = entries
            .filter { $0.timing.totalDuration != nil }
            .sorted { ($0.timing.totalDuration ?? 0) > ($1.timing.totalDuration ?? 0) }
            .prefix(5)
        return listSection(title: "Slowest 5", entries: Array(top)) { entry in
            Text(formatDuration(entry.timing.totalDuration ?? 0))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.lpDanger)
        }
    }

    private var failuresSection: some View {
        let failures = entries.filter { $0.error != nil || ($0.statusCode ?? 0) >= 400 }
        guard !failures.isEmpty else { return AnyView(EmptyView()) }
        let top = Array(failures.prefix(5))
        return AnyView(
            listSection(title: "Recent Failures", entries: top) { entry in
                Text(entry.statusCode.map(String.init) ?? "—")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.lpDanger)
            }
        )
    }

    private var hostSection: some View {
        // Aggregate by host: count + total bandwidth + avg duration.
        var byHost: [String: (count: Int, bytes: Int64, durations: [TimeInterval])] = [:]
        for e in entries {
            var bucket = byHost[e.host, default: (0, 0, [])]
            bucket.count += 1
            bucket.bytes += e.responseSize
            if let d = e.timing.totalDuration { bucket.durations.append(d) }
            byHost[e.host] = bucket
        }
        let rows = byHost
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Top Hosts")
            VStack(spacing: 0) {
                ForEach(Array(rows), id: \.key) { host, stats in
                    HStack(spacing: 8) {
                        Image(systemName: "globe").font(.caption).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.isEmpty ? "—" : host)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text("\(stats.count) requests").font(.caption2).foregroundStyle(.tertiary)
                                Text(stats.bytes.formattedSize).font(.caption2).foregroundStyle(.tertiary)
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
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func listSection(
        title: String,
        entries: [NetworkEntry],
        @ViewBuilder trailing: @escaping (NetworkEntry) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(entry.method)
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(methodColor(entry.method), in: Capsule())
                                Text(entry.url.path.isEmpty ? "/" : entry.url.path)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            Text(entry.host)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        trailing(entry)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
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
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No requests yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    // MARK: - Helpers

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET":    return .blue
        case "POST":   return .green
        case "PUT":    return .orange
        case "PATCH":  return .purple
        case "DELETE": return .red
        default:       return .gray
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        t < 1 ? String(format: "%.0fms", t * 1000) : String(format: "%.2fs", t)
    }

    private func average(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func percentile(_ values: [TimeInterval], p: Double) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let idx = min(sorted.count - 1, Int(Double(sorted.count - 1) * p))
        return sorted[idx]
    }
}
