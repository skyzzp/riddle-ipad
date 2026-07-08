import SwiftUI

@main
struct RiddleApp: App {
    @State private var memory = Memory()

    init() {
        // Dev-convenience migration shim: seed the Keychain from the bundled
        // riddle-config.plist on first launch so the device keeps working before
        // the key is entered in Settings. Runs only while the Keychain is empty;
        // once configured (or on a plist-free build) this branch never fires.
        if AppConfig.apiKey.isEmpty,
           let url = Bundle.main.url(forResource: "riddle-config", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = p["apiKey"] as? String, !key.isEmpty {
            AppConfig.apiKey = key
            if let base = p["baseURL"] as? String { AppConfig.baseURL = base }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(memory: memory)
        }
    }
}
