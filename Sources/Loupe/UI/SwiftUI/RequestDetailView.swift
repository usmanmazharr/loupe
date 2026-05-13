import SwiftUI

/// Tabbed detail view: Overview / Request / Response / Timeline / cURL.
struct RequestDetailView: View {

    @ObservedObject var entry: NetworkEntry
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedTab: Tab = .overview
    @State private var bodySearch: String = ""
    @State private var copied: Bool = false

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case request  = "Request"
        case response = "Response"
        case timeline = "Timeline"
        case curl     = "cURL"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .overview: return "doc.text"
            case .request:  return "arrow.up.circle"
            case .response: return "arrow.down.circle"
            case .timeline: return "timeline.selection"
            case .curl:     return "terminal"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.tfCardBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.tfCardBackground)

            Divider()

            if selectedTab == .request || selectedTab == .response {
                searchBar
                Divider()
            }

            ScrollView {
                Group {
                    switch selectedTab {
                    case .overview:  overviewTab
                    case .request:   requestTab
                    case .response:  responseTab
                    case .timeline:  RequestTimelineView(entry: entry)
                    case .curl:      curlTab
                    }
                }
                .id(selectedTab)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Loupe")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarItems }
        .tfNavigationBar()
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search keys, values…", text: $bodySearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
            if !bodySearch.isEmpty {
                Button {
                    bodySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.tfCardBackground)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MethodBadge(method: entry.method)
                StatusBadge(code: entry.statusCode, status: entry.status)
                if entry.isMocked {
                    Text("MOCKED")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.purple, in: Capsule())
                }
                Spacer()
                if entry.status == .inProgress {
                    ProgressView().scaleEffect(0.75)
                }
            }

            Text(entry.url.absoluteString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                infoChip(icon: "clock", text: entry.timing.formattedDuration)
                infoChip(icon: "arrow.down", text: entry.responseSize > 0 ? entry.responseSize.formattedSize : "—")
                if entry.retryCount > 0 {
                    infoChip(icon: "arrow.clockwise", text: "\(entry.retryCount) retries")
                }
            }
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption.monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
                bodySearch = ""
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.systemImage).font(.system(size: 11))
                Text(tab.rawValue).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedTab == tab ? Color.blue.opacity(0.15) : Color.clear,
                in: Capsule()
            )
            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tabs

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoSection(title: "Request") {
                infoRow("URL", value: entry.url.absoluteString)
                infoRow("Method", value: entry.method)
                infoRow("Date", value: entry.timing.startDate.formatted(date: .abbreviated, time: .standard))
            }
            if !entry.queryParameters.isEmpty {
                infoSection(title: "Query Parameters") {
                    ForEach(entry.queryParameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        infoRow(key, value: value)
                    }
                }
            }
            infoSection(title: "Response") {
                infoRow("Status", value: entry.statusCode.map { "\($0) \(HTTPURLResponse.localizedString(forStatusCode: $0))" } ?? "—")
                infoRow("Size", value: entry.responseSize > 0 ? entry.responseSize.formattedSize : "—")
                infoRow("Content-Type", value: entry.responseContentType.displayName)
            }
            if let error = entry.error {
                infoSection(title: "Error") {
                    infoRow("Domain", value: error.domain)
                    infoRow("Code", value: String(error.code))
                    infoRow("Message", value: error.localizedDescription)
                }
            }
        }
    }

    private var requestTab: some View {
        let formatted = entry.formattedRequestText
        return blockSection(title: "Request", text: formatted)
    }

    private var responseTab: some View {
        if let _ = entry.responseBody {
            return AnyView(blockSection(title: "Response", text: entry.formattedResponseText))
        } else if entry.status.isTerminal {
            return AnyView(blockSection(title: "Response", text: entry.formattedResponseText))
        } else {
            return AnyView(
                infoSection(title: "Response") {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for response…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            )
        }
    }

    private var curlTab: some View {
        let curl = CURLGenerator.generate(from: entry)
        return blockSection(title: "cURL Command", text: curl)
    }

    // MARK: - Reusable sections

    private func blockSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    ExportManager.copyToClipboard(text)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            highlightedText(text, term: bodySearch)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.tfCardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightedText(_ source: String, term: String) -> Text {
        guard !term.isEmpty else { return Text(source) }
        var attributed = AttributedString(source)
        let lowerSource = source.lowercased()
        let lowerTerm   = term.lowercased()
        var searchStart = lowerSource.startIndex
        while let range = lowerSource.range(of: lowerTerm, range: searchStart ..< lowerSource.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.6)
                attributed[attrRange].foregroundColor = .black
            }
            searchStart = range.upperBound
        }
        return Text(attributed)
    }

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tfCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                    Text("Back").font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.tfInk)
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                Task { await LogManager.shared.setPinned(!entry.isPinned, id: entry.effectiveID) }
            } label: {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(entry.isPinned ? Color.yellow : Color(uiColor: .label))
            }
            Menu {
                Button {
                    ExportManager.copyToClipboard(entry.formattedResponseText)
                } label: {
                    Label("Copy Response", systemImage: "arrow.down.doc")
                }
                Button {
                    ExportManager.copyToClipboard(entry.formattedRequestText)
                } label: {
                    Label("Copy Request", systemImage: "arrow.up.doc")
                }
                Button {
                    ExportManager.copyToClipboard(CURLGenerator.generate(from: entry))
                } label: {
                    Label("Copy cURL", systemImage: "terminal")
                }
                Divider()
                Button {
                    ExportManager.presentShareSheet(for: [entry], format: .plainText, from: nil)
                } label: {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

// MARK: - URL/HEADERS/RESPONSE formatting

extension NetworkEntry {

    fileprivate func headerLiteral(_ headers: [String: String]) -> String {
        if headers.isEmpty { return "[:]" }
        let pairs = headers.map { #""\#($0.key)": "\#($0.value)""# }.joined(separator: ", ")
        return "[\(pairs)]"
    }

    fileprivate func bodyString(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "" }
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }
        if let str = String(data: data, encoding: .utf8) { return str }
        return "<binary \(data.count) bytes>"
    }

    var formattedRequestText: String {
        var out = "URL: \n\(url.absoluteString)\n\n"
        out += "METHOD: \n\(method)\n\n"
        out += "HEADERS: \n\(headerLiteral(requestHeaders))"
        let body = bodyString(requestBody)
        if !body.isEmpty {
            out += "\n\nBODY: \n\(body)"
        }
        return out
    }

    var formattedResponseText: String {
        var out = "URL: \n\(url.absoluteString)\n\n"
        out += "HEADERS: \n\(headerLiteral(responseHeaders))\n\n"
        if let code = statusCode {
            out += "STATUS: \n\(code)\n\n"
        }
        let body = bodyString(responseBody)
        out += "RESPONSE: \n\(body.isEmpty ? "<no body>" : body)"
        return out
    }
}
