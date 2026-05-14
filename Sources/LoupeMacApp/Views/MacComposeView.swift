import SwiftUI
import AppKit

struct MacComposeHeader: Identifiable, Equatable {
    let id = UUID()
    var key:   String = ""
    var value: String = ""
}

struct MacComposeResponse {
    let statusCode: Int
    let headers:    [String: String]
    let body:       Data
    let duration:   TimeInterval
}

/// Postman-like request composer for the macOS companion. Fires from the Mac
/// (not from the connected iOS device).
struct MacComposeView: View {

    @State private var url:       String = ""
    @State private var method:    String = "GET"
    @State private var headers:   [MacComposeHeader] = [MacComposeHeader(key: "Content-Type", value: "application/json")]
    @State private var bodyText:  String = ""
    @State private var isSending: Bool = false
    @State private var response:  MacComposeResponse? = nil
    @State private var errorText: String? = nil
    @State private var showCurlPaste: Bool = false
    @State private var curlInput: String = ""

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pasteCurlBar
                urlSection
                headersSection
                bodySection
                sendButton
                if let errorText { errorView(errorText) }
                if let response { responseSection(response) }
            }
            .padding(16)
        }
        .sheet(isPresented: $showCurlPaste) {
            pasteCurlSheet
        }
    }

    // MARK: - Paste cURL

    private var pasteCurlBar: some View {
        Button {
            curlInput = NSPasteboard.general.string(forType: .string) ?? ""
            showCurlPaste = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "terminal").font(.system(size: 11, weight: .semibold))
                Text("Paste cURL").font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.lpInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.lpAccentSoft, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var pasteCurlSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Paste cURL")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { showCurlPaste = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lpFog)
                Button("Import") {
                    if let parsed = CURLParserMac.parse(curlInput) {
                        apply(parsed)
                        showCurlPaste = false
                    } else {
                        errorText = "Couldn't parse that as a curl command."
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(curlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Loupe will fill the URL, method, headers, and body from the curl command.")
                .font(.system(size: 11))
                .foregroundStyle(Color.lpFog)
            TextEditor(text: $curlInput)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)
                .padding(6)
                .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.lpHairline, lineWidth: 1)
                )
        }
        .padding(16)
        .frame(width: 560, height: 360)
    }

    private func apply(_ parsed: CURLParserMac.Parsed) {
        url = parsed.url
        method = parsed.method
        bodyText = parsed.body
        var rows = parsed.headers.map { MacComposeHeader(key: $0.key, value: $0.value) }
        if rows.isEmpty {
            rows = [MacComposeHeader(key: "Content-Type", value: "application/json")]
        }
        headers = rows
        errorText = nil
        response = nil
    }

    // MARK: - URL + method

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Endpoint")
            HStack(spacing: 8) {
                Picker("", selection: $method) {
                    ForEach(methods, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
                TextField("https://api.example.com/users", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    // MARK: - Headers

    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("Headers")
                Spacer()
                Button {
                    headers.append(MacComposeHeader())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.lpAccent)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 4) {
                ForEach($headers) { $h in
                    HStack(spacing: 6) {
                        TextField("Key", text: $h.key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        TextField("Value", text: $h.value)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        Button {
                            headers.removeAll { $0.id == h.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.lpFog)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Body")
            TextEditor(text: $bodyText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 140)
                .padding(6)
                .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.lpHairline, lineWidth: 1)
                )
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack {
                if isSending {
                    ProgressView().scaleEffect(0.6).tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSending ? "Sending…" : "Send")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(canSend ? Color.lpAccent : Color.lpFog, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!canSend || isSending)
    }

    private var canSend: Bool {
        URL(string: url.trimmingCharacters(in: .whitespaces))?.scheme?.lowercased().hasPrefix("http") == true
    }

    // MARK: - Response

    private func responseSection(_ r: MacComposeResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sectionTitle("Response")
                Spacer()
                Text("\(r.statusCode)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.lpStatusColor(r.statusCode))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lpStatusColor(r.statusCode).opacity(0.10), in: Capsule())
                Text(String(format: "%.0f ms", r.duration * 1000))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.lpFog)
            }
            if !r.headers.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("HEADERS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.lpFog)
                    ForEach(r.headers.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        HStack(alignment: .top) {
                            Text(k)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lpFog)
                                .frame(width: 160, alignment: .leading)
                            Text(v)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                        }
                    }
                }
                .padding(8)
                .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 8))
            }
            if !r.body.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BODY · \(r.body.count) bytes")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.lpFog)
                    Text(String(data: r.body, encoding: .utf8) ?? "<binary>")
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.lpDanger)
            Text(message).font(.system(size: 11))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lpDanger.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.lpFog)
    }

    // MARK: - Send

    private func send() {
        guard let target = URL(string: url.trimmingCharacters(in: .whitespaces)) else { return }
        var request = URLRequest(url: target)
        request.httpMethod = method
        for h in headers where !h.key.isEmpty {
            request.setValue(h.value, forHTTPHeaderField: h.key)
        }
        if !bodyText.isEmpty, method != "GET", method != "HEAD" {
            request.httpBody = bodyText.data(using: .utf8)
        }

        isSending = true
        response = nil
        errorText = nil
        let started = Date()

        URLSession.shared.dataTask(with: request) { data, resp, err in
            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                isSending = false
                if let err {
                    errorText = err.localizedDescription
                    return
                }
                guard let http = resp as? HTTPURLResponse else {
                    errorText = "Non-HTTP response"
                    return
                }
                let headerDict = http.allHeaderFields.reduce(into: [String: String]()) { acc, kv in
                    if let k = kv.key as? String, let v = kv.value as? String { acc[k] = v }
                }
                response = MacComposeResponse(
                    statusCode: http.statusCode,
                    headers:    headerDict,
                    body:       data ?? Data(),
                    duration:   elapsed
                )
            }
        }.resume()
    }
}
