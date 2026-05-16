import SwiftUI

struct RequestDetailView: View {

    @ObservedObject var entry: NetworkEntry
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedTab: Tab = .overview
    @State private var bodySearch: String = ""
    @State private var copied: Bool = false
    @State private var currentMatchIndex: Int = 0
    @State private var requestExpanded = true
    @State private var responseExpanded = true

    @State private var reqBodyTree: JSONNode?
    @State private var resBodyTree: JSONNode?

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
                    ForEach(Tab.allCases) { tab in tabButton(tab) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.lpCardBackground)

            Divider()

            ScrollViewReader { proxy in
                if selectedTab == .requestResponse {
                    searchBar(proxy: proxy)
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
        .onAppear { parseTrees() }
        .onChange(of: entry.requestBody) { _ in parseTrees() }
        .onChange(of: entry.responseBody) { _ in parseTrees() }
    }

    private func parseTrees() {
        reqBodyTree = entry.requestBody.flatMap { JSONFormatter.parse($0) }
        resBodyTree = entry.responseBody.flatMap { JSONFormatter.parse($0) }
    }

    // MARK: - Match anchors (using cached trees)

    private func allMatchAnchors() -> [String] {
        guard !bodySearch.isEmpty else { return [] }
        let term = bodySearch.lowercased()
        var anchors: [String] = []

        // Request matches
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
        if let tree = reqBodyTree {
            anchors.append(contentsOf: JSONTreeView.matchingNodeIDs(in: tree, term: bodySearch))
        }

        // Response matches
        if let code = entry.statusCode, String(code).lowercased().contains(term) { anchors.append("res-status") }
        if let tree = resBodyTree {
            anchors.append(contentsOf: JSONTreeView.matchingNodeIDs(in: tree, term: bodySearch))
        }

        return anchors
    }

    private func navigateMatch(delta: Int, proxy: ScrollViewProxy) {
        let anchors = allMatchAnchors()
        guard !anchors.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + delta + anchors.count) % anchors.count
        let target = anchors[currentMatchIndex]

        if !requestExpanded { requestExpanded = true }
        if !responseExpanded { responseExpanded = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    // MARK: - Search Bar

    private func searchBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search…", text: $bodySearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .onChange(of: bodySearch) { _ in currentMatchIndex = 0 }
            if !bodySearch.isEmpty {
                let count = allMatchAnchors().count
                if count > 0 {
                    Text("\(min(currentMatchIndex + 1, count)) of \(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    Button { navigateMatch(delta: -1, proxy: proxy) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.orange)
                    }
                    Button { navigateMatch(delta: 1, proxy: proxy) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.orange)
                    }
                } else {
                    Text("0 results")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
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

    // MARK: - Request & Response Tab

    private var requestResponseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── REQUEST card ──
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    title: "Request", icon: "arrow.up.right", iconColor: .blue,
                    expanded: $requestExpanded,
                    matchCount: requestMatchCount()
                )
                if requestExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        field("URL", value: entry.url.absoluteString, id: "req-url")
                        field("Method", value: entry.method, id: "req-method")
                        if !entry.requestHeaders.isEmpty {
                            kvBlock("Headers", dict: entry.requestHeaders, sectionId: "req-headers")
                        }
                        if !entry.queryParameters.isEmpty {
                            kvBlock("Query Parameters", dict: entry.queryParameters, sectionId: "req-query")
                        }
                        jsonBody(tree: reqBodyTree, data: entry.requestBody)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 12)
                }
            }
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 10))

            // ── RESPONSE card ──
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    title: "Response", icon: "arrow.down.left", iconColor: .green,
                    expanded: $responseExpanded,
                    matchCount: responseMatchCount()
                )
                if responseExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        if let code = entry.statusCode {
                            HStack(spacing: 8) {
                                StatusBadge(code: code, status: entry.status)
                                hlMono("\(code) \(HTTPURLResponse.localizedString(forStatusCode: code))")
                            }
                            .id("res-status")
                        }
                        jsonBody(tree: resBodyTree, data: entry.responseBody)
                    }
                    .padding(.horizontal, 12).padding(.bottom, 12)
                }
            }
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Shared section header

    private func sectionHeader(title: String, icon: String, iconColor: Color, expanded: Binding<Bool>, matchCount: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 12)
                Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(iconColor)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                if !bodySearch.isEmpty && matchCount > 0 {
                    Text("\(matchCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.orange, in: Capsule())
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Field helpers

    private func field(_ label: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            hlMono(value).textSelection(.enabled)
        }
        .id(id)
    }

    private func kvBlock(_ title: String, dict: [String: String], sectionId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 4) {
                    hlText(key + ":", baseColor: .jsonKey).font(.system(size: 12, weight: .medium, design: .monospaced))
                    hlText(value, baseColor: .secondary).font(.system(size: 12, design: .monospaced)).lineLimit(3)
                    Spacer()
                    Button { ExportManager.copyToClipboard(value) } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                .padding(.vertical, 3)
                .id("kv-\(sectionId)-\(key)")
            }
        }
    }

    @ViewBuilder
    private func jsonBody(tree: JSONNode?, data: Data?) -> some View {
        if let tree {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                JSONTreeView(node: tree, initiallyExpanded: true, searchTerm: bodySearch)
                cpyBtn(data)
            }
        } else if let data, !data.isEmpty, let str = String(data: data, encoding: .utf8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                hlMono(str).textSelection(.enabled)
                cpyBtn(data)
            }
        } else {
            Text("(empty body)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func cpyBtn(_ data: Data?) -> some View {
        if let data, !data.isEmpty {
            HStack {
                Spacer()
                Button {
                    let text: String
                    if let obj = try? JSONSerialization.jsonObject(with: data),
                       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                       let s = String(data: pretty, encoding: .utf8) { text = s }
                    else { text = String(data: data, encoding: .utf8) ?? "" }
                    ExportManager.copyToClipboard(text)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { copied = false } }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Match Counting

    private func requestMatchCount() -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()
        var c = entry.url.absoluteString.lowercased().countOccurrences(of: term)
        if entry.method.lowercased().contains(term) { c += 1 }
        for (k, v) in entry.requestHeaders { if k.lowercased().contains(term) { c += 1 }; if v.lowercased().contains(term) { c += 1 } }
        for (k, v) in entry.queryParameters { if k.lowercased().contains(term) { c += 1 }; if v.lowercased().contains(term) { c += 1 } }
        if let tree = reqBodyTree { c += JSONTreeView.countMatches(in: tree, term: bodySearch) }
        return c
    }

    private func responseMatchCount() -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()
        var c = 0
        if let code = entry.statusCode, String(code).lowercased().contains(term) { c += 1 }
        if let tree = resBodyTree { c += JSONTreeView.countMatches(in: tree, term: bodySearch) }
        return c
    }

    // MARK: - Highlighted text

    private func hlMono(_ source: String) -> Text {
        bodySearch.isEmpty
            ? Text(source).font(.system(size: 12, design: .monospaced)).foregroundColor(.primary)
            : hlText(source, baseColor: .primary).font(.system(size: 12, design: .monospaced))
    }

    private func hlText(_ source: String, baseColor: Color) -> Text {
        guard !bodySearch.isEmpty else { return Text(source).foregroundColor(baseColor) }
        var attr = AttributedString(source)
        let lower = source.lowercased(), term = bodySearch.lowercased()
        var start = lower.startIndex
        while let range = lower.range(of: term, range: start..<lower.endIndex) {
            if let r = Range(range, in: attr) { attr[r].backgroundColor = .yellow.opacity(0.6); attr[r].foregroundColor = .black }
            start = range.upperBound
        }
        return Text(attr).foregroundColor(baseColor)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MethodBadge(method: entry.method)
                StatusBadge(code: entry.statusCode, status: entry.status)
                if entry.isMocked { Text("MOCKED").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(.purple, in: Capsule()) }
                Spacer()
                if entry.status == .inProgress { ProgressView().scaleEffect(0.75) }
            }
            Text(entry.url.absoluteString).font(.system(size: 13, design: .monospaced)).foregroundStyle(.primary).lineLimit(3).textSelection(.enabled)
            HStack(spacing: 16) {
                infoChip(icon: "clock", text: entry.timing.formattedDuration)
                infoChip(icon: "arrow.down", text: entry.responseSize > 0 ? entry.responseSize.formattedSize : "—")
                if entry.retryCount > 0 { infoChip(icon: "arrow.clockwise", text: "\(entry.retryCount) retries") }
            }
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) { Image(systemName: icon).font(.caption2); Text(text).font(.caption.monospacedDigit()) }.foregroundStyle(.secondary)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab; bodySearch = "" } } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.systemImage).font(.system(size: 11))
                Text(tab.rawValue).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selectedTab == tab ? Color.blue.opacity(0.15) : Color.clear, in: Capsule())
            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
        }.buttonStyle(.plain)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoSection(title: "Request") {
                infoRow("URL", value: entry.url.absoluteString)
                infoRow("Method", value: entry.method)
                infoRow("Date", value: entry.timing.startDate.formatted(date: .abbreviated, time: .standard))
            }
            if !entry.queryParameters.isEmpty {
                infoSection(title: "Query Parameters") {
                    ForEach(entry.queryParameters.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in infoRow(k, value: v) }
                }
            }
            infoSection(title: "Response") {
                infoRow("Status", value: entry.statusCode.map { "\($0) \(HTTPURLResponse.localizedString(forStatusCode: $0))" } ?? "—")
                infoRow("Size", value: entry.responseSize > 0 ? entry.responseSize.formattedSize : "—")
                infoRow("Content-Type", value: entry.responseContentType.displayName)
            }
            if let error = entry.error {
                infoSection(title: "Error") { infoRow("Domain", value: error.domain); infoRow("Code", value: String(error.code)); infoRow("Message", value: error.localizedDescription) }
            }
        }
    }

    private var curlTab: some View {
        let curl = CURLGenerator.generate(from: entry)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CURL COMMAND").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    ExportManager.copyToClipboard(curl); withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { copied = false } }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.blue.opacity(0.15), in: Capsule()).foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }
            Text(curl).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func infoSection<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).padding(.bottom, 2)
            content()
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(key).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline).textSelection(.enabled) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)); Text("Back").font(.system(size: 15, weight: .medium)) }.foregroundStyle(Color.lpInk)
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { Task { await LogManager.shared.setPinned(!entry.isPinned, id: entry.effectiveID) } } label: {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin").foregroundStyle(entry.isPinned ? Color.yellow : Color(uiColor: .label))
            }
            Menu {
                Button { ExportManager.copyToClipboard(entry.formattedResponseText) } label: { Label("Copy Response", systemImage: "arrow.down.doc") }
                Button { ExportManager.copyToClipboard(entry.formattedRequestText) } label: { Label("Copy Request", systemImage: "arrow.up.doc") }
                Button { ExportManager.copyToClipboard(CURLGenerator.generate(from: entry)) } label: { Label("Copy cURL", systemImage: "terminal") }
                Divider()
                Button { ExportManager.presentShareSheet(for: [entry], format: .plainText, from: nil) } label: { Label("Share…", systemImage: "square.and.arrow.up") }
            } label: { Image(systemName: "square.and.arrow.up") }
        }
    }
}

// MARK: - Formatting

extension NetworkEntry {
    fileprivate func headerLiteral(_ headers: [String: String]) -> String {
        if headers.isEmpty { return "[:]" }
        return "[" + headers.map { #""\#($0.key)": "\#($0.value)""# }.joined(separator: ", ") + "]"
    }
    fileprivate func bodyString(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "" }
        if let obj = try? JSONSerialization.jsonObject(with: data), let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]), let str = String(data: pretty, encoding: .utf8) { return str }
        return String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
    }
    var formattedRequestText: String {
        var out = "URL: \n\(url.absoluteString)\n\nMETHOD: \n\(method)\n\nHEADERS: \n\(headerLiteral(requestHeaders))"
        let body = bodyString(requestBody); if !body.isEmpty { out += "\n\nBODY: \n\(body)" }; return out
    }
    var formattedResponseText: String {
        var out = "URL: \n\(url.absoluteString)\n\nHEADERS: \n\(headerLiteral(responseHeaders))\n\n"
        if let code = statusCode { out += "STATUS: \n\(code)\n\n" }
        let body = bodyString(responseBody); out += "RESPONSE: \n\(body.isEmpty ? "<no body>" : body)"; return out
    }
}

extension String {
    func countOccurrences(of term: String) -> Int {
        guard !term.isEmpty else { return 0 }
        var count = 0; var s = startIndex
        while let r = range(of: term, range: s..<endIndex) { count += 1; s = r.upperBound }
        return count
    }
}
