import SwiftUI

/// Tabbed detail view: Overview / Request / Response / Timeline / cURL.
struct RequestDetailView: View {

    @ObservedObject var entry: NetworkEntry
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedTab: Tab = .overview
    @State private var bodySearch: String = ""
    @State private var copied: Bool = false
    @State private var currentMatchIndex: Int = 0

    @State private var expandedSections: Set<String> = [
        "req-url", "req-method", "req-headers", "req-query", "req-body",
        "res-status", "res-headers", "res-body"
    ]


    enum Tab: String, CaseIterable, Identifiable {
        case overview        = "Overview"
        case requestResponse = "Request & Response"
        case timeline        = "Timeline"
        case curl            = "cURL"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .overview:        return "doc.text"
            case .requestResponse: return "arrow.up.arrow.down"
            case .timeline:        return "timeline.selection"
            case .curl:            return "terminal"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lpCardBackground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.lpCardBackground)

            Divider()

            ScrollViewReader { proxy in
                if selectedTab == .requestResponse {
                    searchBarWithCount(proxy: proxy)
                    Divider()
                }

                ScrollView {
                    Group {
                        switch selectedTab {
                        case .overview:        overviewTab
                        case .requestResponse: requestResponseTab
                        case .timeline:        RequestTimelineView(entry: entry)
                        case .curl:            curlTab
                        }
                    }
                    .id(selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Loupe")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarItems }
    }

    // MARK: - Individual match navigation

    private var allMatchAnchors: [String] {
        guard !bodySearch.isEmpty else { return [] }
        let term = bodySearch.lowercased()
        var anchors: [String] = []

        if entry.url.absoluteString.lowercased().contains(term) { anchors.append("req-url") }
        if entry.method.lowercased().contains(term) { anchors.append("req-method") }
        for (k, v) in entry.requestHeaders.sorted(by: { $0.key < $1.key }) {
            if k.lowercased().contains(term) || v.lowercased().contains(term) {
                anchors.append("kv-req-headers-\(k)")
            }
        }
        for (k, v) in entry.queryParameters.sorted(by: { $0.key < $1.key }) {
            if k.lowercased().contains(term) || v.lowercased().contains(term) {
                anchors.append("kv-req-query-\(k)")
            }
        }
        if let data = entry.requestBody, let tree = JSONFormatter.parse(data) {
            anchors.append(contentsOf: JSONTreeView.matchingNodeIDs(in: tree, term: bodySearch))
        } else if let data = entry.requestBody, let str = String(data: data, encoding: .utf8), str.lowercased().contains(term) {
            anchors.append("req-body")
        }

        if let code = entry.statusCode, String(code).contains(term) { anchors.append("res-status") }
        for (k, v) in entry.responseHeaders.sorted(by: { $0.key < $1.key }) {
            if k.lowercased().contains(term) || v.lowercased().contains(term) {
                anchors.append("kv-res-headers-\(k)")
            }
        }
        if let data = entry.responseBody, let tree = JSONFormatter.parse(data) {
            anchors.append(contentsOf: JSONTreeView.matchingNodeIDs(in: tree, term: bodySearch))
        } else if let data = entry.responseBody, let str = String(data: data, encoding: .utf8), str.lowercased().contains(term) {
            anchors.append("res-body")
        }

        return anchors
    }

    private var totalMatchCount: Int { allMatchAnchors.count }

    private func navigateMatch(delta: Int, proxy: ScrollViewProxy) {
        let anchors = allMatchAnchors
        guard !anchors.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + delta + anchors.count) % anchors.count
        let target = anchors[currentMatchIndex]

        // Ensure parent section is expanded when navigating
        if target.hasPrefix("kv-req-headers") { expandedSections.insert("req-headers") }
        else if target.hasPrefix("kv-req-query") { expandedSections.insert("req-query") }
        else if target.hasPrefix("kv-res-headers") { expandedSections.insert("res-headers") }
        else if target.hasPrefix("req-") { expandedSections.insert(target) }
        else if target.hasPrefix("res-") { expandedSections.insert(target) }
        else { expandedSections.insert("req-body"); expandedSections.insert("res-body") }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func searchBarWithCount(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search request & response…", text: $bodySearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .onChange(of: bodySearch) { _ in currentMatchIndex = 0 }
            if !bodySearch.isEmpty {
                let count = totalMatchCount
                if count > 0 {
                    Text("\(min(currentMatchIndex + 1, count)) of \(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())

                    Button { navigateMatch(delta: -1, proxy: proxy) } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }

                    Button { navigateMatch(delta: 1, proxy: proxy) } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                } else {
                    Text("0 results")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Button { bodySearch = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.lpCardBackground)
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

    // MARK: - Merged Request & Response Tab

    private var requestResponseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REQUEST")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            treeSection(id: "req-url", title: "URL", icon: "link", count: nil) {
                highlightedMonoText(entry.url.absoluteString)
                    .textSelection(.enabled)
            }

            treeSection(id: "req-method", title: "Method", icon: "arrow.up.right", count: nil) {
                highlightedMonoText(entry.method)
            }

            treeSection(id: "req-headers", title: "Headers", icon: "list.bullet.rectangle", count: entry.requestHeaders.count) {
                keyValueTree(entry.requestHeaders, sectionId: "req-headers")
            }

            if !entry.queryParameters.isEmpty {
                treeSection(id: "req-query", title: "Query Parameters", icon: "questionmark.circle", count: entry.queryParameters.count) {
                    keyValueTree(entry.queryParameters, sectionId: "req-query")
                }
            }

            bodyTreeSection(data: entry.requestBody, contentType: entry.requestContentType, id: "req-body", label: "Body")

            Divider().padding(.vertical, 4)

            Text("RESPONSE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if let code = entry.statusCode {
                treeSection(id: "res-status", title: "Status", icon: "number", count: nil) {
                    HStack(spacing: 8) {
                        StatusBadge(code: code, status: entry.status)
                        highlightedMonoText("\(code) \(HTTPURLResponse.localizedString(forStatusCode: code))")
                    }
                }
            }

            treeSection(id: "res-headers", title: "Headers", icon: "list.bullet.rectangle", count: entry.responseHeaders.count) {
                keyValueTree(entry.responseHeaders, sectionId: "res-headers")
            }

            if entry.responseBody != nil || entry.status.isTerminal {
                bodyTreeSection(data: entry.responseBody, contentType: entry.responseContentType, id: "res-body", label: "Body")
            } else {
                treeSection(id: "res-body", title: "Body", icon: "doc.text", count: nil) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for response…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Tree Section

    private func treeSection<Content: View>(
        id: String,
        title: String,
        icon: String,
        count: Int?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSections.contains(id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedSections.remove(id) }
                    else { expandedSections.insert(id) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let count {
                        Text("(\(count))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !bodySearch.isEmpty {
                        let sectionMatches = sectionMatchCount(id: id)
                        if sectionMatches > 0 {
                            Text("\(sectionMatches)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .padding(.leading, 32)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 10))
        .id(id)
    }

    private func sectionMatchCount(id: String) -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()
        switch id {
        case "req-url": return entry.url.absoluteString.lowercased().countOccurrences(of: term)
        case "req-method": return entry.method.lowercased().contains(term) ? 1 : 0
        case "req-headers": return countKVMatches(entry.requestHeaders, term: term)
        case "req-query": return countKVMatches(entry.queryParameters, term: term)
        case "req-body": return bodyMatchCount(data: entry.requestBody, term: term)
        case "res-status":
            if let code = entry.statusCode { return String(code).contains(term) ? 1 : 0 }
            return 0
        case "res-headers": return countKVMatches(entry.responseHeaders, term: term)
        case "res-body": return bodyMatchCount(data: entry.responseBody, term: term)
        default: return 0
        }
    }

    private func countKVMatches(_ dict: [String: String], term: String) -> Int {
        var count = 0
        for (k, v) in dict {
            if k.lowercased().contains(term) { count += 1 }
            if v.lowercased().contains(term) { count += 1 }
        }
        return count
    }

    private func bodyMatchCount(data: Data?, term: String) -> Int {
        guard let data else { return 0 }
        if let tree = JSONFormatter.parse(data) {
            return JSONTreeView.countMatches(in: tree, term: bodySearch)
        }
        if let str = String(data: data, encoding: .utf8) {
            return str.lowercased().countOccurrences(of: term)
        }
        return 0
    }

    // MARK: - Key-Value Tree

    private func keyValueTree(_ dict: [String: String], sectionId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 4) {
                    highlightedText(key + ":", baseColor: .jsonKey)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    highlightedText(value, baseColor: .secondary)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(3)
                    Spacer()
                    Button {
                        ExportManager.copyToClipboard(value)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 3)
                .id("kv-\(sectionId)-\(key)")
                if key != dict.sorted(by: { $0.key < $1.key }).last?.key {
                    Divider()
                }
            }
        }
    }

    // MARK: - Body Tree Section

    @ViewBuilder
    private func bodyTreeSection(data: Data?, contentType: ContentType, id: String, label: String) -> some View {
        let formatted = BodyFormatter.format(data: data, contentType: contentType)
        switch formatted {
        case .json(let raw, let tree):
            treeSection(id: id, title: label, icon: "curlybraces", count: nil) {
                if let tree {
                    JSONTreeView(node: tree, initiallyExpanded: true, searchTerm: bodySearch)
                } else {
                    highlightedMonoText(raw)
                        .textSelection(.enabled)
                }

                HStack {
                    Spacer()
                    Button {
                        ExportManager.copyToClipboard(raw)
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
            }
        case .xml(let str):
            treeSection(id: id, title: label, icon: "chevron.left.forwardslash.chevron.right", count: nil) {
                highlightedMonoText(str)
                    .textSelection(.enabled)
                copyButton(str)
            }
        case .text(let str):
            treeSection(id: id, title: label, icon: "doc.text", count: nil) {
                highlightedMonoText(str)
                    .textSelection(.enabled)
                copyButton(str)
            }
        case .image(_, let sub):
            treeSection(id: id, title: label, icon: "photo", count: nil) {
                Text("Image (\(sub))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case .pdf:
            treeSection(id: id, title: label, icon: "doc.richtext", count: nil) {
                Text("PDF document")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case .binary(let desc):
            treeSection(id: id, title: label, icon: "doc", count: nil) {
                Text(desc)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case .empty:
            treeSection(id: id, title: label, icon: "doc", count: nil) {
                Text("(empty)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func copyButton(_ text: String) -> some View {
        HStack {
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
    }

    // MARK: - Highlighted text helpers

    private func highlightedMonoText(_ source: String) -> Text {
        if bodySearch.isEmpty {
            return Text(source)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
        }
        return highlightedText(source, baseColor: .primary)
            .font(.system(size: 12, design: .monospaced))
    }

    private func highlightedText(_ source: String, baseColor: Color) -> Text {
        guard !bodySearch.isEmpty else { return Text(source).foregroundColor(baseColor) }
        var attributed = AttributedString(source)
        let lowerSource = source.lowercased()
        let lowerTerm   = bodySearch.lowercased()
        var searchStart = lowerSource.startIndex
        while let range = lowerSource.range(of: lowerTerm, range: searchStart ..< lowerSource.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.6)
                attributed[attrRange].foregroundColor = .black
            }
            searchStart = range.upperBound
        }
        return Text(attributed).foregroundColor(baseColor)
    }

    // MARK: - Overview Tab (unchanged)

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

    private var curlTab: some View {
        let curl = CURLGenerator.generate(from: entry)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CURL COMMAND")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    ExportManager.copyToClipboard(curl)
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
            Text(curl)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Reusable sections

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
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
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
                .foregroundStyle(Color.lpInk)
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

// MARK: - String occurrence counting

extension String {
    func countOccurrences(of term: String) -> Int {
        guard !term.isEmpty else { return 0 }
        var count = 0
        var searchStart = startIndex
        while let range = range(of: term, range: searchStart..<endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }
}
