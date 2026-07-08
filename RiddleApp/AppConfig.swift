import Foundation
import RiddleKit

/// App configuration. The API key lives in the Keychain; base URL + model names
/// in UserDefaults with baked defaults. Replaces the Phase-1 bundled plist.
enum AppConfig {
    private static let d = UserDefaults.standard
    private enum K {
        static let apiKey = "apiKey"          // Keychain account
        static let baseURL = "baseURL"        // UserDefaults keys
        static let replyModel = "replyModel"
        static let sideModel = "sideModel"
    }

    static var apiKey: String {
        get { Keychain.get(K.apiKey) ?? "" }
        set {
            if newValue.isEmpty { Keychain.delete(K.apiKey) }
            else { Keychain.set(newValue, for: K.apiKey) }
        }
    }
    static var baseURL: String {
        get { d.string(forKey: K.baseURL) ?? Persona.defaultBaseURL }
        set { d.set(newValue, forKey: K.baseURL) }
    }
    static var replyModel: String {
        get { d.string(forKey: K.replyModel) ?? Persona.replyModel }
        set { d.set(newValue, forKey: K.replyModel) }
    }
    static var sideModel: String {
        get { d.string(forKey: K.sideModel) ?? Persona.sideModel }
        set { d.set(newValue, forKey: K.sideModel) }
    }

    /// The first-run gate: Settings auto-opens when this is false.
    static var isConfigured: Bool { !apiKey.isEmpty }

    /// Provider presets fill the base URL; all are OpenAI-compatible. The field
    /// stays editable for anything not listed.
    static let providerPresets: [(name: String, baseURL: String)] = [
        ("OpenRouter", "https://openrouter.ai/api/v1"),
        ("OpenAI", "https://api.openai.com/v1"),
        ("Groq", "https://api.groq.com/openai/v1"),
        ("Local", "http://localhost:1234/v1"),
    ]
}
