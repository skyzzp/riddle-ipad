import SwiftUI
import UIKit
import RiddleKit

struct SettingsView: View {
    let memory: Memory
    let onClose: () -> Void

    @State private var baseURL = AppConfig.baseURL
    // Never prefill the secret: iOS SecureFields clear on the first keystroke, so a
    // prefilled key gets clobbered by any edit (or an accidental focus + Done). Start
    // blank; a stored key is kept unless a new non-empty value is entered.
    @State private var apiKey = ""
    @State private var replyModel = AppConfig.replyModel
    @State private var sideModel = AppConfig.sideModel
    @State private var presetName = ""
    @State private var testResult = ""
    @State private var testing = false
    @State private var showWipeConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Preset", selection: $presetName) {
                        Text("Custom").tag("")
                        ForEach(AppConfig.providerPresets, id: \.name) { p in
                            Text(p.name).tag(p.name)
                        }
                    }
                    .onChange(of: presetName) { _, name in
                        if let p = AppConfig.providerPresets.first(where: { $0.name == name }) {
                            baseURL = p.baseURL
                        }
                    }
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(AppConfig.isConfigured ? "API key stored — leave blank to keep"
                                                        : "API Key", text: $apiKey)
                }
                Section("Models") {
                    TextField("Reply model", text: $replyModel)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Side model", text: $sideModel)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Test") {
                    Button(testing ? "Testing…" : "Test connection") { runTest() }
                        .disabled(testing)
                    if !testResult.isEmpty {
                        Text(testResult).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Wipe Tom's memory", role: .destructive) { showWipeConfirm = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); onClose() }
                }
            }
            .confirmationDialog("Erase everything Tom remembers? This cannot be undone.",
                                isPresented: $showWipeConfirm, titleVisibility: .visible) {
                Button("Wipe memory", role: .destructive) { memory.wipe() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        AppConfig.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        // Only overwrite the stored key when a new one was actually typed; a blank
        // field means "keep the existing key" (see the @State note above).
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty { AppConfig.apiKey = key }
        AppConfig.replyModel = replyModel.trimmingCharacters(in: .whitespaces)
        AppConfig.sideModel = sideModel.trimmingCharacters(in: .whitespaces)
    }

    private func runTest() {
        testing = true; testResult = ""
        // Test the newly-typed key if present, else the one already stored.
        let typedKey = apiKey.trimmingCharacters(in: .whitespaces)
        let cfg = OracleConfig(baseURL: baseURL.trimmingCharacters(in: .whitespaces),
                               apiKey: typedKey.isEmpty ? AppConfig.apiKey : typedKey,
                               model: replyModel.trimmingCharacters(in: .whitespaces))
        // Re-encode to a STANDARD PNG at read time: Xcode's "Compress PNG Files"
        // rewrites bundled PNGs into Apple's proprietary CgBI format, which the
        // model's image decoder rejects (400). UIImage decodes CgBI fine and
        // pngData() always emits a standard PNG the API accepts.
        guard let url = Bundle.main.url(forResource: "test-fixture", withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path),
              let data = img.pngData() else {
            testResult = "test fixture missing"; testing = false; return
        }
        let b64 = data.base64EncodedString()
        Task { @MainActor in
            var out = ""
            do {
                for try await s in OracleClient(config: cfg).ask(imageBase64: b64) {
                    out += s + " "
                    testResult = out
                }
                if out.isEmpty { testResult = "connected, but empty reply" }
            } catch {
                testResult = "failed: \(error)"
            }
            testing = false
        }
    }
}
