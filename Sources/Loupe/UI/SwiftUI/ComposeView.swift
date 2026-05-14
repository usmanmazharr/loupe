import SwiftUI

// MARK: - Header row

struct ComposeHeader: Identifiable, Equatable {
    let id = UUID()
    var key:   String = ""
    var value: String = ""
}

// MARK: - Response snapshot

struct ComposeResponse {
    let statusCode: Int
    let headers:    [String: String]
    let body:       Data
    let duration:   TimeInterval
    let mimeType:   String?
}

// MARK: - Compose view

/// Postman-like request composer. Fire a request with custom URL, method,
/// headers, and body — response is shown inline, and the request is also
/// captured by the interceptor so it appears in the main entry list.
public struct ComposeView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var url:       String = ""
    @State private var method:    String = "GET"
    @State private var headers:   [ComposeHeader] = [ComposeHeader(key: "Content-Type", value: "application/json")]
    @State private var bodyText:  String = ""
    @State private var isSending: Bool = false
    @State private var response:  ComposeResponse? = nil
    @State private var error:     String? = nil

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    urlSection
                    headersSection
                    bodySection
                    sendButton
                    if let error { errorView(error) }
                    if let response { responseSection(response) }
                }
                .padding(16)
            }
            .background(Color.lpBackground.ignoresSafeArea())
            .navigationTitle("Compose")
            .navigationBarTitleDisplayMode(.inline)
            .lpNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LPBackButton { dismiss() }
                }
            }
        }
    }

    // MARK: - URL + method

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Endpoint")
            HStack(spacing: 8) {
                Menu {
                    ForEach(methods, id: \.self) { m in
                        Button(m) { method = m }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(method)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(Color.methodColor(for: method))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.lpFog)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.methodColor(for: method).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                TextField("https://api.example.com/users", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Headers

    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Headers")
                Spacer()
                Button {
                    headers.append(ComposeHeader())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lpAccent)
                }
            }
            VStack(spacing: 6) {
                ForEach($headers) { $h in
                    HStack(spacing: 6) {
                        TextField("Key", text: $h.key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 6))
                        TextField("Value", text: $h.value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 6))
                        Button {
                            headers.removeAll { $0.id == h.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lpFog)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Body")
            Group {
                if #available(iOS 16, *) {
                    TextEditor(text: $bodyText)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                } else {
                    TextEditor(text: $bodyText)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .padding(8)
            .frame(minHeight: 120)
            .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("{ \"key\": \"value\" }")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.lpMist)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSending ? "Sending…" : "Send")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canSend ? Color.lpAccent : Color.lpFog, in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!canSend || isSending)
    }

    private var canSend: Bool {
        URL(string: url.trimmingCharacters(in: .whitespaces))?.scheme?.lowercased().hasPrefix("http") == true
    }

    // MARK: - Response

    private func responseSection(_ r: ComposeResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionTitle("Response")
                Spacer()
                Text("\(r.statusCode)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.statusColor(for: r.statusCode))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.statusColor(for: r.statusCode).opacity(0.10), in: Capsule())
                Text(String(format: "%.0f ms", r.duration * 1000))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.lpFog)
            }

            if !r.headers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEADERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.lpFog)
                    ForEach(r.headers.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        HStack(alignment: .top) {
                            Text(k)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lpFog)
                                .frame(width: 140, alignment: .leading)
                            Text(v)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.lpInk)
                                .textSelection(.enabled)
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 8))
            }

            if !r.body.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BODY · \(r.body.count) bytes")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.lpFog)
                    Text(String(data: r.body, encoding: .utf8) ?? "<binary>")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.lpInk)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.lpDanger)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.lpInk)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lpDanger.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.lpFog)
    }

    // MARK: - Send logic

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
        error = nil
        let started = Date()

        URLSession.shared.dataTask(with: request) { data, resp, err in
            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                isSending = false
                if let err {
                    error = err.localizedDescription
                    return
                }
                guard let http = resp as? HTTPURLResponse else {
                    error = "Non-HTTP response"
                    return
                }
                let headerDict = http.allHeaderFields.reduce(into: [String: String]()) { acc, kv in
                    if let k = kv.key as? String, let v = kv.value as? String { acc[k] = v }
                }
                response = ComposeResponse(
                    statusCode: http.statusCode,
                    headers:    headerDict,
                    body:       data ?? Data(),
                    duration:   elapsed,
                    mimeType:   http.mimeType
                )
            }
        }.resume()
    }
}
