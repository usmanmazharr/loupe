import SwiftUI

struct MacRequestDetailView: View {

    let entry: MacNetworkEntry
    @EnvironmentObject private var appState: AppState
    @State private var tab: Tab = .overview
    @State private var bodySearch: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var requestExpanded = true
    @State private var responseExpanded = true
    @State private var reqBodyTree: MacJSONNode?
    @State private var resBodyTree: MacJSONNode?

    enum Tab: String, CaseIterable { case overview = "Overview"; case requestResponse = "Request & Response"; case curl = "cURL" }

    var body: some View {
        VStack(spacing: 0) {
            headerView.padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
            Divider()
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button(t.rawValue) { tab = t; bodySearch = ""; currentMatchIndex = 0 }
                        .buttonStyle(.plain).font(.callout.weight(tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? .primary : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(tab == t ? Color.accentColor.opacity(0.1) : .clear)
                }
                Spacer()
            }.padding(.horizontal, 16).background(.bar)
            Divider()

            ScrollViewReader { proxy in
                if tab == .requestResponse { searchBar(proxy: proxy); Divider() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch tab {
                        case .overview: overviewTab
                        case .requestResponse: requestResponseTab
                        case .curl: curlTab
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { parseTrees() }
        .onChange(of: entry.id) { _ in parseTrees() }
        .onChange(of: entry.responseBody) { _ in parseTrees() }
        .onChange(of: entry.requestBody) { _ in parseTrees() }
        .id(entry.id)
    }

    private func parseTrees() {
        reqBodyTree = entry.requestBody.flatMap { MacJSONNode.parse($0) }
        resBodyTree = entry.responseBody.flatMap { MacJSONNode.parse($0) }
    }

    // MARK: - Match Navigation

    private func allMatchAnchors() -> [String] {
        guard !bodySearch.isEmpty else { return [] }
        let term = bodySearch.lowercased()
        var anchors: [String] = []
        if entry.url.absoluteString.lowercased().contains(term) { anchors.append("req-url") }
        if entry.method.lowercased().contains(term) { anchors.append("req-method") }
        for (k, v) in entry.requestHeaders.sorted(by: { $0.key < $1.key }) {
            if k.lowercased().contains(term) || v.lowercased().contains(term) { anchors.append("kv-req-headers-\(k)") }
        }
        for (k, v) in entry.queryParameters.sorted(by: { $0.key < $1.key }) {
            if k.lowercased().contains(term) || v.lowercased().contains(term) { anchors.append("kv-req-query-\(k)") }
        }
        if let tree = reqBodyTree { anchors.append(contentsOf: MacJSONTreeView.matchingNodeIDs(in: tree, term: bodySearch)) }
        if let code = entry.statusCode, String(code).lowercased().contains(term) { anchors.append("res-status") }
        if let tree = resBodyTree { anchors.append(contentsOf: MacJSONTreeView.matchingNodeIDs(in: tree, term: bodySearch)) }
        return anchors
    }

    private func navigateMatch(delta: Int, proxy: ScrollViewProxy) {
        let anchors = allMatchAnchors()
        guard !anchors.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + delta + anchors.count) % anchors.count
        let target = anchors[currentMatchIndex]

        let needsExpand = !requestExpanded || !responseExpanded
        if !requestExpanded { requestExpanded = true }
        if !responseExpanded { responseExpanded = true }

        let delay: Double = needsExpand ? 0.4 : 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(target, anchor: .center)
            }
            // Second attempt for deeply nested nodes that may not have laid out yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func searchBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search…", text: $bodySearch).textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                .onChange(of: bodySearch) { _ in currentMatchIndex = 0 }
            if !bodySearch.isEmpty {
                let count = allMatchAnchors().count
                if count > 0 {
                    Text("\(min(currentMatchIndex + 1, count)) of \(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.orange.opacity(0.12), in: Capsule())
                    Button { navigateMatch(delta: -1, proxy: proxy) } label: { Image(systemName: "chevron.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.orange) }.buttonStyle(.plain)
                    Button { navigateMatch(delta: 1, proxy: proxy) } label: { Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.orange) }.buttonStyle(.plain)
                } else {
                    Text("0 results").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Button { bodySearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                methodBadge
                if let code = entry.statusCode { statusBadge(code) }
                if entry.isMocked { mockBadge }
                Spacer()
                Button { appState.setPinned(entry, pinned: !entry.isPinned) } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin").foregroundStyle(entry.isPinned ? Color.yellow : .secondary)
                }.buttonStyle(.borderless).help(entry.isPinned ? "Unpin" : "Pin")
                if entry.status == .inProgress { ProgressView().scaleEffect(0.7) }
            }
            Text(entry.url.absoluteString).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).lineLimit(3)
            HStack(spacing: 16) {
                chip(icon: "clock", text: entry.timing.formattedDuration)
                chip(icon: "arrow.down", text: entry.responseSize > 0 ? entry.responseSize.macFormattedSize : "—")
                if entry.retryCount > 0 { chip(icon: "arrow.clockwise", text: "\(entry.retryCount) retries") }
            }
        }
    }

    private var methodBadge: some View { Text(entry.method).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(methodColor, in: RoundedRectangle(cornerRadius: 5)) }
    private func statusBadge(_ code: Int) -> some View { Text(String(code)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(statusColor(code)).padding(.horizontal, 7).padding(.vertical, 3).background(statusColor(code).opacity(0.12), in: RoundedRectangle(cornerRadius: 5)) }
    private var mockBadge: some View { Text("MOCK").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 2).background(.purple, in: Capsule()) }
    private func chip(icon: String, text: String) -> some View { Label(text, systemImage: icon).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }

    // MARK: - Request & Response Tab

    private var requestResponseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── REQUEST ──
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(title: "Request", icon: "arrow.up.right", iconColor: .blue, expanded: $requestExpanded, matchCount: requestMatchCount())
                if requestExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledField("URL", value: entry.url.absoluteString, id: "req-url")
                        labeledField("Method", value: entry.method, id: "req-method")
                        if !entry.requestHeaders.isEmpty { kvBlock("Headers", dict: entry.requestHeaders, sectionId: "req-headers") }
                        if !entry.queryParameters.isEmpty { kvBlock("Query Parameters", dict: entry.queryParameters, sectionId: "req-query") }
                        jsonBody(tree: reqBodyTree, data: entry.requestBody)
                    }.padding(.horizontal, 12).padding(.bottom, 12)
                }
            }.background(RoundedRectangle(cornerRadius: 10).fill(.quinary))

            // ── RESPONSE ──
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(title: "Response", icon: "arrow.down.left", iconColor: .green, expanded: $responseExpanded, matchCount: responseMatchCount())
                if responseExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        if let code = entry.statusCode {
                            HStack(spacing: 8) { statusBadge(code); hlMono("\(code) \(HTTPURLResponse.localizedString(forStatusCode: code))") }.id("res-status")
                        }
                        jsonBody(tree: resBodyTree, data: entry.responseBody)
                    }.padding(.horizontal, 12).padding(.bottom, 12)
                }
            }.background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
        }
    }

    private func sectionHeader(title: String, icon: String, iconColor: Color, expanded: Binding<Bool>, matchCount: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.wrappedValue.toggle() } } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 12)
                Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(iconColor)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                if !bodySearch.isEmpty && matchCount > 0 {
                    Text("\(matchCount)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 1).background(Color.orange, in: Capsule())
                }
            }.padding(.vertical, 8).padding(.horizontal, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func labeledField(_ label: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            hlMono(value).textSelection(.enabled)
        }.id(id)
    }

    private func kvBlock(_ title: String, dict: [String: String], sectionId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 4) {
                    hlText(key + ":", baseColor: .blue).font(.system(size: 12, weight: .medium, design: .monospaced))
                    hlText(value, baseColor: .secondary).font(.system(size: 12, design: .monospaced)).lineLimit(3)
                    Spacer()
                }
                .padding(.vertical, 3)
                .contextMenu {
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string) } label: { Label("Copy Value", systemImage: "doc.on.doc") }
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(key, forType: .string) } label: { Label("Copy Key", systemImage: "textformat") }
                }
                .id("kv-\(sectionId)-\(key)")
            }
        }
    }

    @ViewBuilder
    private func jsonBody(tree: MacJSONNode?, data: Data?) -> some View {
        if let tree {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ScrollView(.horizontal, showsIndicators: true) {
                    MacJSONTreeView(node: tree, initiallyExpanded: true, searchTerm: bodySearch)
                        .frame(minWidth: 600)
                }
                cpyBtn(data)
            }
        } else if let data, !data.isEmpty, let str = String(data: data, encoding: .utf8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                ScrollView(.horizontal, showsIndicators: true) {
                    hlMono(str).textSelection(.enabled)
                }
                cpyBtn(data)
            }
        } else {
            Text("(empty body)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private func cpyBtn(_ data: Data?) -> some View {
        if let data, !data.isEmpty {
            HStack {
                Spacer()
                Button {
                    let text: String
                    if let obj = try? JSONSerialization.jsonObject(with: data), let p = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]), let s = String(data: p, encoding: .utf8) { text = s } else { text = String(data: data, encoding: .utf8) ?? "" }
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
                } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption.weight(.medium)) }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    // MARK: - Match Counting

    private func requestMatchCount() -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased(); var c = entry.url.absoluteString.lowercased().macCountOccurrences(of: term)
        if entry.method.lowercased().contains(term) { c += 1 }
        for (k, v) in entry.requestHeaders { if k.lowercased().contains(term) { c += 1 }; if v.lowercased().contains(term) { c += 1 } }
        for (k, v) in entry.queryParameters { if k.lowercased().contains(term) { c += 1 }; if v.lowercased().contains(term) { c += 1 } }
        if let tree = reqBodyTree { c += MacJSONTreeView.countMatches(in: tree, term: bodySearch) }
        return c
    }

    private func responseMatchCount() -> Int {
        guard !bodySearch.isEmpty else { return 0 }
        let term = bodySearch.lowercased(); var c = 0
        if let code = entry.statusCode, String(code).lowercased().contains(term) { c += 1 }
        if let tree = resBodyTree { c += MacJSONTreeView.countMatches(in: tree, term: bodySearch) }
        return c
    }

    // MARK: - Highlighted Text

    private func hlMono(_ source: String) -> Text {
        bodySearch.isEmpty ? Text(source).font(.system(size: 12, design: .monospaced)).foregroundColor(.primary) : hlText(source, baseColor: .primary).font(.system(size: 12, design: .monospaced))
    }

    private func hlText(_ source: String, baseColor: Color) -> Text {
        guard !bodySearch.isEmpty else { return Text(source).foregroundColor(baseColor) }
        var attr = AttributedString(source); let lower = source.lowercased(), term = bodySearch.lowercased(); var start = lower.startIndex
        while let range = lower.range(of: term, range: start..<lower.endIndex) {
            if let r = Range(range, in: attr) { attr[r].backgroundColor = .yellow.opacity(0.6); attr[r].foregroundColor = .black }
            start = range.upperBound
        }
        return Text(attr).foregroundColor(baseColor)
    }

    // MARK: - Overview / cURL

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoSection("Request") { row("URL", entry.url.absoluteString); row("Method", entry.method); row("Date", entry.timing.startDate.formatted(date: .abbreviated, time: .standard))
                if !entry.queryParameters.isEmpty { Divider(); ForEach(entry.queryParameters.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in row(k, v) } }
            }
            infoSection("Response") { row("Status", entry.statusCode.map { "\($0) \(HTTPURLResponse.localizedString(forStatusCode: $0))" } ?? "—"); row("Size", entry.responseSize > 0 ? entry.responseSize.macFormattedSize : "—"); row("Content-Type", entry.responseContentType.displayName) }
            if let err = entry.error {
                let isCancelled = err.domain == "NSURLErrorDomain" && err.code == -999
                let hasValidResponse = entry.statusCode != nil
                if isCancelled && hasValidResponse {
                    // Response received before cancellation — suppress error
                } else if isCancelled {
                    infoSection("Error") { row("Status", "Request Cancelled") }
                } else {
                    infoSection("Error") { row("Domain", err.domain); row("Code", String(err.code)); row("Message", err.localizedDescription) }
                }
            }
        }
    }

    private var curlTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("cURL Command").font(.headline); Spacer()
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.curlCommand, forType: .string) } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption) }.buttonStyle(.bordered).controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) { Text(entry.curlCommand).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading) }.background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func infoSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase); content() }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) { Text(key).font(.caption).foregroundStyle(.secondary); Text(value).font(.callout).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
    }

    private var methodColor: Color { switch entry.method { case "GET": return .blue; case "POST": return .green; case "PUT": return .orange; case "PATCH": return .purple; case "DELETE": return .red; default: return .gray } }
    private func statusColor(_ code: Int) -> Color { switch code { case 200..<300: return .green; case 300..<400: return .blue; case 400..<500: return .orange; default: return .red } }
}

extension String {
    fileprivate func macCountOccurrences(of term: String) -> Int {
        guard !term.isEmpty else { return 0 }; var count = 0; var s = startIndex
        while let r = range(of: term, range: s..<endIndex) { count += 1; s = r.upperBound }; return count
    }
}

extension MacNetworkEntry {
    fileprivate func bodyString(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "" }
        if let obj = try? JSONSerialization.jsonObject(with: data), let p = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]), let s = String(data: p, encoding: .utf8) { return s }
        return String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
    }
    fileprivate func headerLiteral(_ headers: [String: String]) -> String {
        if headers.isEmpty { return "[:]" }; return "[" + headers.map { #""\#($0.key)": "\#($0.value)""# }.joined(separator: ", ") + "]"
    }
    var formattedRequest: String {
        var out = "URL: \n\(url.absoluteString)\n\nMETHOD: \n\(method)\n\nHEADERS: \n\(headerLiteral(requestHeaders))"
        let body = bodyString(requestBody); if !body.isEmpty { out += "\n\nBODY: \n\(body)" }; return out
    }
    var formattedResponse: String {
        var out = "URL: \n\(url.absoluteString)\n\nHEADERS: \n\(headerLiteral(responseHeaders))\n\n"
        if let code = statusCode { out += "STATUS: \n\(code)\n\n" }
        let body = bodyString(responseBody); out += "RESPONSE: \n\(body.isEmpty ? "<no body>" : body)"; return out
    }
}

private extension Int { var macFormattedSize: String { Int64(self).macFormattedSize } }
