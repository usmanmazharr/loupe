import SwiftUI

struct MacRequestDetailView: View {

    let entry: MacNetworkEntry
    @EnvironmentObject private var appState: AppState
    @State private var tab: Tab = .overview
    @State private var bodySearch: String = ""
    @State private var expandedSections: Set<String> = ["url", "method", "headers", "query", "body", "status"]

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case request  = "Request"
        case response = "Response"
        case curl     = "cURL"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)

            Divider()

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button(t.rawValue) { tab = t; bodySearch = "" }
                        .buttonStyle(.plain)
                        .font(.callout.weight(tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(tab == t ? Color.accentColor.opacity(0.1) : .clear)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .background(.bar)

            Divider()

            if tab == .request || tab == .response {
                searchBar
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .overview:  overviewTab
                    case .request:   requestTreeTab
                    case .response:  responseTreeTab
                    case .curl:      curlTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Search Bar

    private var totalMatchCount: Int {
        guard !bodySearch.isEmpty else { return 0 }
        return tab == .request ? requestMatchCount : responseMatchCount
    }

    private var requestMatchCount: Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()
        var count = 0
        if entry.url.absoluteString.lowercased().contains(term) { count += 1 }
        if entry.method.lowercased().contains(term) { count += 1 }
        for (k, v) in entry.requestHeaders {
            if k.lowercased().contains(term) { count += 1 }
            if v.lowercased().contains(term) { count += 1 }
        }
        for (k, v) in entry.queryParameters {
            if k.lowercased().contains(term) { count += 1 }
            if v.lowercased().contains(term) { count += 1 }
        }
        if let data = entry.requestBody, let tree = MacJSONNode.parse(data) {
            count += MacJSONTreeView.countMatches(in: tree, term: bodySearch)
        } else if let data = entry.requestBody, let str = String(data: data, encoding: .utf8) {
            count += str.lowercased().macCountOccurrences(of: term)
        }
        return count
    }

    private var responseMatchCount: Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()
        var count = 0
        if entry.url.absoluteString.lowercased().contains(term) { count += 1 }
        if let code = entry.statusCode, String(code).contains(term) { count += 1 }
        for (k, v) in entry.responseHeaders {
            if k.lowercased().contains(term) { count += 1 }
            if v.lowercased().contains(term) { count += 1 }
        }
        if let data = entry.responseBody, let tree = MacJSONNode.parse(data) {
            count += MacJSONTreeView.countMatches(in: tree, term: bodySearch)
        } else if let data = entry.responseBody, let str = String(data: data, encoding: .utf8) {
            count += str.lowercased().macCountOccurrences(of: term)
        }
        return count
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search in \(tab == .request ? "request" : "response")…", text: $bodySearch)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
            if !bodySearch.isEmpty {
                Text("\(totalMatchCount) match\(totalMatchCount == 1 ? "" : "es")")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(totalMatchCount > 0 ? Color.orange : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (totalMatchCount > 0 ? Color.orange : Color.secondary).opacity(0.12),
                        in: Capsule()
                    )
                Button {
                    bodySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                methodBadge
                if let code = entry.statusCode { statusBadge(code) }
                if entry.isMocked { mockBadge }
                Spacer()
                Button {
                    appState.setPinned(entry, pinned: !entry.isPinned)
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(entry.isPinned ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(entry.isPinned ? "Unpin" : "Pin")
                if entry.status == .inProgress { ProgressView().scaleEffect(0.7) }
            }
            Text(entry.url.absoluteString)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
            HStack(spacing: 16) {
                chip(icon: "clock",      text: entry.timing.formattedDuration)
                chip(icon: "arrow.down", text: entry.responseSize > 0 ? entry.responseSize.macFormattedSize : "—")
                if entry.retryCount > 0 { chip(icon: "arrow.clockwise", text: "\(entry.retryCount) retries") }
            }
        }
    }

    private var methodBadge: some View {
        Text(entry.method)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(methodColor, in: RoundedRectangle(cornerRadius: 5))
    }

    private func statusBadge(_ code: Int) -> some View {
        Text(String(code))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(statusColor(code))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusColor(code).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private var mockBadge: some View {
        Text("MOCK")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.purple, in: Capsule())
    }

    private func chip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    // MARK: - Request Tree Tab

    private var requestTreeTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            treeSection(id: "url", title: "URL", icon: "link") {
                highlightedMono(entry.url.absoluteString)
                    .textSelection(.enabled)
            }

            treeSection(id: "method", title: "Method", icon: "arrow.up.right") {
                highlightedMono(entry.method)
            }

            treeSection(id: "headers", title: "Headers (\(entry.requestHeaders.count))", icon: "list.bullet.rectangle") {
                keyValueTree(entry.requestHeaders)
            }

            if !entry.queryParameters.isEmpty {
                treeSection(id: "query", title: "Query Parameters (\(entry.queryParameters.count))", icon: "questionmark.circle") {
                    keyValueTree(entry.queryParameters)
                }
            }

            bodyTreeSection(data: entry.requestBody, label: "Body")
        }
    }

    // MARK: - Response Tree Tab

    private var responseTreeTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            treeSection(id: "url", title: "URL", icon: "link") {
                highlightedMono(entry.url.absoluteString)
                    .textSelection(.enabled)
            }

            if let code = entry.statusCode {
                treeSection(id: "status", title: "Status", icon: "number") {
                    HStack(spacing: 8) {
                        statusBadge(code)
                        highlightedMono("\(code) \(HTTPURLResponse.localizedString(forStatusCode: code))")
                    }
                }
            }

            treeSection(id: "headers", title: "Headers (\(entry.responseHeaders.count))", icon: "list.bullet.rectangle") {
                keyValueTree(entry.responseHeaders)
            }

            if entry.responseBody != nil || entry.status.isTerminal {
                bodyTreeSection(data: entry.responseBody, label: "Body")
            } else {
                treeSection(id: "body", title: "Body", icon: "doc.text") {
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

                    Spacer()

                    if !bodySearch.isEmpty {
                        let matches = sectionMatchCount(id: id)
                        if matches > 0 {
                            Text("\(matches)")
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
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func sectionMatchCount(id: String) -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased()

        if tab == .request {
            switch id {
            case "url": return entry.url.absoluteString.lowercased().macCountOccurrences(of: term)
            case "method": return entry.method.lowercased().contains(term) ? 1 : 0
            case "headers": return countKVMatches(entry.requestHeaders, term: term)
            case "query": return countKVMatches(entry.queryParameters, term: term)
            case "body": return bodyMatchCount(data: entry.requestBody, term: term)
            default: return 0
            }
        } else {
            switch id {
            case "url": return entry.url.absoluteString.lowercased().macCountOccurrences(of: term)
            case "status":
                if let code = entry.statusCode { return String(code).contains(term) ? 1 : 0 }
                return 0
            case "headers": return countKVMatches(entry.responseHeaders, term: term)
            case "body": return bodyMatchCount(data: entry.responseBody, term: term)
            default: return 0
            }
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
        if let tree = MacJSONNode.parse(data) {
            return MacJSONTreeView.countMatches(in: tree, term: bodySearch)
        }
        if let str = String(data: data, encoding: .utf8) {
            return str.lowercased().macCountOccurrences(of: term)
        }
        return 0
    }

    // MARK: - Key-Value Tree

    private func keyValueTree(_ dict: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 4) {
                    highlightedText(key + ":", baseColor: .blue)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    highlightedText(value, baseColor: .secondary)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(3)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 3)
                if key != dict.sorted(by: { $0.key < $1.key }).last?.key {
                    Divider()
                }
            }
        }
    }

    // MARK: - Body Tree Section

    @ViewBuilder
    private func bodyTreeSection(data: Data?, label: String) -> some View {
        if let data, !data.isEmpty {
            if let tree = MacJSONNode.parse(data) {
                treeSection(id: "body", title: label, icon: "curlybraces") {
                    MacJSONTreeView(node: tree, initiallyExpanded: true, searchTerm: bodySearch)
                    copyBodyButton(data)
                }
            } else if let str = String(data: data, encoding: .utf8) {
                treeSection(id: "body", title: label, icon: "doc.text") {
                    highlightedMono(str)
                        .textSelection(.enabled)
                    copyBodyButton(data)
                }
            } else {
                treeSection(id: "body", title: label, icon: "doc") {
                    Text("<binary \(data.count) bytes>")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            treeSection(id: "body", title: label, icon: "doc") {
                Text("(empty)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func copyBodyButton(_ data: Data) -> some View {
        HStack {
            Spacer()
            Button {
                let text: String
                if let obj = try? JSONSerialization.jsonObject(with: data),
                   let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                   let str = String(data: pretty, encoding: .utf8) {
                    text = str
                } else {
                    text = String(data: data, encoding: .utf8) ?? ""
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Highlighted Text

    private func highlightedMono(_ source: String) -> Text {
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
        while let range = lowerSource.range(of: lowerTerm, range: searchStart..<lowerSource.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.6)
                attributed[attrRange].foregroundColor = .black
            }
            searchStart = range.upperBound
        }
        return Text(attributed).foregroundColor(baseColor)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoSection("Request") {
                row("URL",    entry.url.absoluteString)
                row("Method", entry.method)
                row("Date",   entry.timing.startDate.formatted(date: .abbreviated, time: .standard))
                if !entry.queryParameters.isEmpty {
                    Divider()
                    ForEach(entry.queryParameters.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        row(k, v)
                    }
                }
            }
            infoSection("Response") {
                row("Status",       entry.statusCode.map { "\($0) \(HTTPURLResponse.localizedString(forStatusCode: $0))" } ?? "—")
                row("Size",         entry.responseSize > 0 ? entry.responseSize.macFormattedSize : "—")
                row("Content-Type", entry.responseContentType.displayName)
            }
            if let err = entry.error {
                infoSection("Error") {
                    row("Domain",  err.domain)
                    row("Code",    String(err.code))
                    row("Message", err.localizedDescription)
                }
            }
        }
    }

    private var curlTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("cURL Command").font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.curlCommand, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(entry.curlCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Reusable

    private func infoSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var methodColor: Color {
        switch entry.method {
        case "GET":    return .blue
        case "POST":   return .green
        case "PUT":    return .orange
        case "PATCH":  return .purple
        case "DELETE": return .red
        default:       return .gray
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default:        return .red
        }
    }
}

// MARK: - String helpers

extension String {
    fileprivate func macCountOccurrences(of term: String) -> Int {
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

// MARK: - Formatting helpers

extension MacNetworkEntry {
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

    fileprivate func headerLiteral(_ headers: [String: String]) -> String {
        if headers.isEmpty { return "[:]" }
        let pairs = headers.map { #""\#($0.key)": "\#($0.value)""# }.joined(separator: ", ")
        return "[\(pairs)]"
    }

    var formattedRequest: String {
        var out = "URL: \n\(url.absoluteString)\n\n"
        out += "METHOD: \n\(method)\n\n"
        out += "HEADERS: \n\(headerLiteral(requestHeaders))"
        let body = bodyString(requestBody)
        if !body.isEmpty { out += "\n\nBODY: \n\(body)" }
        return out
    }

    var formattedResponse: String {
        var out = "URL: \n\(url.absoluteString)\n\n"
        out += "HEADERS: \n\(headerLiteral(responseHeaders))\n\n"
        if let code = statusCode { out += "STATUS: \n\(code)\n\n" }
        let body = bodyString(responseBody)
        out += "RESPONSE: \n\(body.isEmpty ? "<no body>" : body)"
        return out
    }
}

private extension Int {
    var macFormattedSize: String { Int64(self).macFormattedSize }
}
