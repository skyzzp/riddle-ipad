import Foundation

public struct OracleConfig {
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var maxTokens: Int
    public init(baseURL: String = Persona.defaultBaseURL, apiKey: String,
                model: String = Persona.replyModel, maxTokens: Int = 2000) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey; self.model = model; self.maxTokens = maxTokens
    }
}

/// Build the OpenAI-compatible streaming chat-completions body with a data-URI
/// image part. Mirrors HttpOracle::ask (oracle.rs) but via JSONSerialization.
public func chatCompletionsBody(config: OracleConfig, systemPrompt: String,
                                userText: String, imageBase64: String) -> Data {
    let body: [String: Any] = [
        "model": config.model,
        "stream": true,
        "max_tokens": config.maxTokens,
        "messages": [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": [
                ["type": "text", "text": userText],
                ["type": "image_url",
                 "image_url": ["url": "data:image/png;base64,\(imageBase64)"]],
            ]],
        ],
    ]
    return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
}
