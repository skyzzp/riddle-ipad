import Foundation

/// Build the OpenAI-compatible `messages` for a reply turn:
/// system (persona + remembered notes) → the verbatim ring as alternating
/// user/assistant turns (a turn whose transcription hasn't landed contributes
/// only its assistant line) → the current page as a user message with the image.
public func replyMessages(persona: String, store: MemoryStore,
                          imageBase64: String, userText: String) -> [[String: Any]] {
    var messages: [[String: Any]] = []

    var system = persona
    if !store.notes.isEmpty {
        system += "\n\nWhat you remember about her:\n"
            + store.notes.map { "- \($0)" }.joined(separator: "\n")
    }
    messages.append(["role": "system", "content": system])

    for turn in store.ring {
        if let her = turn.herText, !her.isEmpty {
            messages.append(["role": "user", "content": her])
        }
        messages.append(["role": "assistant", "content": turn.tomReply])
    }

    messages.append(["role": "user", "content": [
        ["type": "text", "text": userText],
        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(imageBase64)"]],
    ]])
    return messages
}

/// Body builder for a pre-assembled `messages` array (memory-aware turns).
public func chatCompletionsBody(config: OracleConfig, messages: [[String: Any]],
                                stream: Bool = true) -> Data {
    let body: [String: Any] = [
        "model": config.model,
        "stream": stream,
        "max_tokens": config.maxTokens,
        "messages": messages,
    ]
    return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
}
