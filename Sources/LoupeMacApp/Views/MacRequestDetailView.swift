import SwiftUI

/// Detail panel: Overview / Request / Response / cURL tabs for a selected entry.
struct MacRequestDetailView: View {

    let entry: MacNetworkEntry
    @EnvironmentObject private var appState: AppState
    @State private var tab: Tab = .overview
    @State private var bodySearch: String = ""

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

            // Body search bar — only on Request / Response tabs.
            if tab == .request || tab == .response {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search in \(tab == .request ? "request" : "response")…", text: $bodySearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                    if !bodySearch.isEmpty {
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
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .overview:  overviewTab
                    case .request:   requestTab
                    case .response:  responseTab
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
                chip(icon: "clock",     text: entry.timing.formattedDuration)
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

    // MARK: - Tabs

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

    private var requestTab: some View {
        let formatted = entry.formattedRequest
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Request").font(.headline)
                Spacer()
                copyButton(text: formatted)
            }
            blockView(text: formatted, highlight: bodySearch)
        }
    }

    private var responseTab: some View {
        let formatted = entry.formattedResponse
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Response").font(.headline)
                if entry.responseSize > 0 {
                    Text("· \(entry.responseSize.macFormattedSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                copyButton(text: formatted)
            }
            blockView(text: formatted, highlight: bodySearch)
        }
    }

    private var curlTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("cURL Command").font(.headline)
                Spacer()
                copyButton(text: entry.curlCommand)
            }
            blockView(text: entry.curlCommand, highlight: "")
        }
    }

    // MARK: - Reusable pieces

    private func copyButton(text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private func blockView(text: String, highlight: String) -> some View {
        let display = highlight.isEmpty ? AttributedString(text) : highlighted(text, term: highlight)
        ScrollView(.horizontal, showsIndicators: false) {
            Text(display)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func highlighted(_ source: String, term: String) -> AttributedString {
        var attributed = AttributedString(source)
        guard !term.isEmpty else { return attributed }
        let lowerSource = source.lowercased()
        let lowerTerm   = term.lowercased()
        var searchStart = lowerSource.startIndex
        while let range = lowerSource.range(of: lowerTerm, range: searchStart ..< lowerSource.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.5)
                attributed[attrRange].foregroundColor = .black
            }
            searchStart = range.upperBound
        }
        return attributed
    }

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
        case 200 ..< 300: return .green
        case 300 ..< 400: return .blue
        case 400 ..< 500: return .orange
        default:          return .red
        }
    }
}

// MARK: - Formatting helpers

extension MacNetworkEntry {
    /// Pretty-prints a JSON body, or returns the raw UTF-8 string, or a placeholder.
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

    /// Renders the dictionary in Swift-literal form: ["key": "value", ...]
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
        if !body.isEmpty {
            out += "\n\nBODY: \n\(body)"
        }
        return out
    }

    var formattedResponse: String {
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

private extension Int {
    var macFormattedSize: String { Int64(self).macFormattedSize }
}
