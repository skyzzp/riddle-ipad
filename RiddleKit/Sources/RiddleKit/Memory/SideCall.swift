import Foundation

/// Non-streaming request that transcribes her page and extracts new notes.
/// The current notes list is sent so the model won't re-extract known facts.
public func sideCallBody(config: OracleConfig, imageBase64: String,
                         currentNotes: [String]) -> Data {
    let known = currentNotes.isEmpty
        ? "(nothing recorded yet)"
        : currentNotes.map { "- \($0)" }.joined(separator: "\n")
    let userText = "Already recorded about the writer:\n\(known)\n\nTranscribe the page and list only NEW notes."
    let messages: [[String: Any]] = [
        ["role": "system", "content": Persona.sidePrompt],
        ["role": "user", "content": [
            ["type": "text", "text": userText],
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(imageBase64)"]],
        ]],
    ]
    let body: [String: Any] = [
        "model": config.model,
        "stream": false,
        "max_tokens": config.maxTokens,
        "messages": messages,
    ]
    return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
}

/// Tolerant parse of the side model's reply. Strips code fences and surrounding
/// prose, isolates the outermost `{...}`, then JSONSerialization; falls back to
/// hand-rolled field extraction. Returns (nil, []) when nothing usable is found.
public func parseSideResponse(_ raw: String) -> (transcription: String?, notes: [String]) {
    let cleaned = raw
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
    guard let start = cleaned.firstIndex(of: "{"),
          let end = cleaned.lastIndex(of: "}"),
          start < end else { return (nil, []) }
    let json = String(cleaned[start...end])

    if let data = json.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let t = obj["transcription"] as? String
        let notes = (obj["notes"] as? [Any])?.compactMap { $0 as? String } ?? []
        return ((t?.isEmpty == false) ? t : nil, notes)
    }
    // Fallback: pull just the transcription via the existing SSE string scanner.
    let t = jsonStrField(json, "transcription")
    return ((t?.isEmpty == false) ? t : nil, [])
}

/// Text-only (no image) compaction request over the current notes list.
public func compactBody(config: OracleConfig, notes: [String]) -> Data {
    let listed = notes.map { "- \($0)" }.joined(separator: "\n")
    let messages: [[String: Any]] = [
        ["role": "system", "content": Persona.compactPrompt],
        ["role": "user", "content": "Notes:\n\(listed)"],
    ]
    let body: [String: Any] = [
        "model": config.model, "stream": false,
        "max_tokens": config.maxTokens, "messages": messages,
    ]
    return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
}

/// Tolerant parse of the compacted notes. Accepts `{"notes":[...]}` or a bare
/// `[...]`. Returns nil (leave the store unchanged) when nothing usable is found.
public func parseCompactedNotes(_ raw: String) -> [String]? {
    let cleaned = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
    // Prefer a {"notes":[...]} object; fall back to a top-level array.
    if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}"), s < e,
       let data = String(cleaned[s...e]).data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let arr = obj["notes"] as? [Any] {
        let notes = arr.compactMap { $0 as? String }
        return notes.isEmpty ? nil : notes
    }
    if let s = cleaned.firstIndex(of: "["), let e = cleaned.lastIndex(of: "]"), s < e,
       let data = String(cleaned[s...e]).data(using: .utf8),
       let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
        let notes = arr.compactMap { $0 as? String }
        return notes.isEmpty ? nil : notes
    }
    return nil
}
