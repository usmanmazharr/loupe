import SwiftUI

/// Mock Engine dashboard — master toggle + per-rule cards.
struct MockEngineView: View {

    @ObservedObject private var engine = MockEngine.shared
    @State private var showAddRule = false

    var body: some View {
        List {
            // Master toggle
            Section {
                HStack {
                    Image(systemName: "theatermasks.fill")
                        .foregroundStyle(engine.isEnabled ? .purple : .secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mock Engine")
                            .font(.headline)
                        Text(engine.isEnabled ? "Active — rules are being applied" : "Disabled globally")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $engine.isEnabled)
                        .labelsHidden()
                }
                .padding(.vertical, 4)
            }

            // Rules
            Section(engine.rules.isEmpty ? "" : "Rules (\(engine.rules.count))") {
                if engine.rules.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "theatermasks")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No mock rules defined")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Add rules programmatically or tap + to create one.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach($engine.rules) { $rule in
                        RuleCard(rule: $rule, engineEnabled: engine.isEnabled)
                    }
                    .onDelete { idx in
                        idx.forEach { engine.rules.remove(at: $0) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mock Engine")
        .navigationBarTitleDisplayMode(.inline)
        .tfNavigationBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddRule = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRule) {
            AddRuleView { newRule in
                engine.add(newRule)
            }
        }
    }
}

// MARK: - Rule card

private struct RuleCard: View {

    @Binding var rule: MockRule
    let engineEnabled: Bool

    private var isEffectivelyActive: Bool { engineEnabled && rule.isEnabled }

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(isEffectivelyActive ? Color.green : Color(uiColor: .systemGray4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Toggle("", isOn: $rule.isEnabled)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }

                HStack(spacing: 6) {
                    if let method = rule.method {
                        Text(method)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.methodColor(for: method), in: Capsule())
                    }
                    Text(String(rule.statusCode))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.statusColor(for: rule.statusCode))
                    if rule.delay > 0 {
                        Label(String(format: "%.1fs", rule.delay), systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if rule.errorCode != nil {
                        Label("Error", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text(rule.urlPattern)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1 : 0.5)
    }
}

// MARK: - Add Rule sheet

struct AddRuleView: View {

    let onSave: (MockRule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var urlPattern  = ""
    @State private var method      = "GET"
    @State private var statusCode  = "200"
    @State private var responseBody = ""
    @State private var delay       = 0.0
    @State private var simulateError = false
    @State private var errorCode   = "URLError.timedOut"

    private let methods = ["GET","POST","PUT","PATCH","DELETE","HEAD","OPTIONS"]

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Rule Name", text: $name)
                    TextField("URL Pattern  (e.g. /api/v1/* or exact URL)", text: $urlPattern)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Request Matching") {
                    Picker("Method", selection: $method) {
                        Text("Any").tag("")
                        ForEach(methods, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Response") {
                    HStack {
                        Text("Status Code")
                        Spacer()
                        TextField("200", text: $statusCode)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response Body (JSON)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $responseBody)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80)
                    }
                }

                Section("Behaviour") {
                    HStack {
                        Text("Delay")
                        Spacer()
                        Text(String(format: "%.1f s", delay))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $delay, in: 0...10, step: 0.5).tint(.orange)

                    Toggle("Simulate URLError", isOn: $simulateError)
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .tfNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { TFBackButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let bodyData = responseBody.isEmpty ? nil : responseBody.data(using: .utf8)
                        let rule = MockRule(
                            name: name.isEmpty ? "Rule" : name,
                            urlPattern: urlPattern,
                            method: method.isEmpty ? nil : method,
                            statusCode: Int(statusCode) ?? 200,
                            responseBody: bodyData,
                            delay: delay,
                            errorCode: simulateError ? .timedOut : nil
                        )
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(urlPattern.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
