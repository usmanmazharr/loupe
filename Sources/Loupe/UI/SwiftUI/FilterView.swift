import SwiftUI

struct FilterView: View {

    @Binding var filter: RequestFilter
    var colorScheme: ColorScheme = .dark
    @State private var availableDomains: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.lpBackground.ignoresSafeArea()

                List {
                    // MARK: - Method
                    Section {
                        chipRow(MethodFilter.allCases, selected: filter.methodFilter, color: .blue) { m in
                            filter.methodFilter = (filter.methodFilter == m) ? .all : m
                        }
                    } header: { sectionHeader("HTTP Method") }

                    // MARK: - Status
                    Section {
                        chipRow(StatusFilter.allCases, selected: filter.statusFilter, colorFor: statusChipColor) { s in
                            filter.statusFilter = (filter.statusFilter == s) ? .all : s
                        }
                    } header: { sectionHeader("Status Code") }

                    // MARK: - Domains
                    if !availableDomains.isEmpty {
                        Section {
                            ForEach(availableDomains, id: \.self) { domain in
                                Toggle(isOn: Binding(
                                    get: { !filter.excludedDomains.contains(domain) },
                                    set: { on in
                                        if on { filter.excludedDomains.remove(domain) }
                                        else  { filter.excludedDomains.insert(domain) }
                                    }
                                )) {
                                    Text(domain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color(uiColor: .label))
                                }
                                .tint(.blue)
                            }
                        } header: { sectionHeader("Domains") }
                    }

                    // MARK: - Duration slider
                    Section {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Max response time")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                                Spacer()
                                Text(filter.maxDuration >= 5.0
                                     ? "Any"
                                     : String(format: "%.0f ms", filter.maxDuration * 1000))
                                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Color(uiColor: .label))
                            }
                            Slider(value: $filter.maxDuration, in: 0.05...5, step: 0.05)
                                .tint(.blue)
                        }
                        .padding(.vertical, 4)
                    } header: { sectionHeader("Response Time") }

                    // MARK: - Sort
                    Section {
                        Picker("Sort by", selection: $filter.sortOrder) {
                            ForEach(SortOrder.allCases) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 14))
                    } header: { sectionHeader("Sort Order") }

                    // MARK: - Options
                    Section {
                        Toggle(isOn: $filter.showOnlyFailed) {
                            Label {
                                Text("Failed only")
                                    .font(.system(size: 14))
                            } icon: {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.lpDanger)
                            }
                        }
                        .tint(.blue)

                    } header: { sectionHeader("Options") }

                    // MARK: - Clear all (always shown when any filter active)
                    if filter.isActive {
                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    filter = RequestFilter()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "xmark.circle")
                                    Text("Clear All Filters")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundStyle(Color.white)
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.red.opacity(0.85))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .lpNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LPBackButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Done").font(.body.weight(.semibold))
                    }
                }
            }
            .task {
                availableDomains = await LogManager.shared.allDomains()
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(colorScheme)
    }

    // MARK: - Generic chip row for CaseIterable filters

    private func chipRow<F: CaseIterable & RawRepresentable & Identifiable & Equatable>(
        _ cases: [F],
        selected: F,
        color: Color = .blue,
        action: @escaping (F) -> Void
    ) -> some View where F.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cases) { item in
                    filterChip(
                        label: item.rawValue,
                        isSelected: selected == item,
                        color: color,
                        action: { action(item) }
                    )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    }

    private func chipRow<F: CaseIterable & RawRepresentable & Identifiable & Equatable>(
        _ cases: [F],
        selected: F,
        colorFor: @escaping (F) -> Color,
        action: @escaping (F) -> Void
    ) -> some View where F.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cases) { item in
                    filterChip(
                        label: item.rawValue,
                        isSelected: selected == item,
                        color: colorFor(item),
                        action: { action(item) }
                    )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    }

    private func filterChip(label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(.uppercase)
    }

    private func statusChipColor(_ f: StatusFilter) -> Color {
        switch f {
        case .all:         return Color(uiColor: .secondaryLabel)
        case .success:     return .lpSuccess
        case .redirect:    return .lpWarning
        case .clientError: return .lpDanger
        case .serverError: return .lpCritical
        case .failed:      return .red
        case .pending:     return .blue
        }
    }
}
