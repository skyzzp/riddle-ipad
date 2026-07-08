import Foundation

/// OpenAI-compatible streaming client. Each `ask` opens one `/chat/completions`
/// request and yields cleaned sentence chunks as SSE deltas arrive — the quill
/// starts writing before the model finishes. Port of HttpOracle::ask (oracle.rs).
public final class OracleClient {
    private let config: OracleConfig
    public init(config: OracleConfig) { self.config = config }

    public func ask(imageBase64: String,
                    store: MemoryStore = MemoryStore()) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = URLRequest(url: URL(string: "\(config.baseURL)/chat/completions")!)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let messages = replyMessages(persona: Persona.systemPrompt, store: store,
                                                 imageBase64: imageBase64,
                                                 userText: "Reply to what is written in the diary.")
                    req.httpBody = chatCompletionsBody(config: config, messages: messages)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        throw OracleError.http(http.statusCode)
                    }
                    var streamer = SentenceStreamer()
                    var deliveredAny = false
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let data = String(trimmed.dropFirst("data:".count))
                            .trimmingCharacters(in: .whitespaces)
                        if data == "[DONE]" { break }
                        guard let frag = sseDeltaContent(data), !frag.isEmpty else { continue }
                        for chunk in streamer.push(frag) {
                            deliveredAny = true; continuation.yield(chunk)
                        }
                    }
                    if let rest = streamer.flush() { deliveredAny = true; continuation.yield(rest) }
                    if !deliveredAny { throw OracleError.empty }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Fire-and-forget: transcribe her page and extract new notes. Non-streaming,
    /// off the hot path. Swallows every error into (nil, []) — a missed side-call
    /// just leaves that turn's user line absent from memory (spec: drop-turn-on-miss).
    public func transcribeAndExtract(imageBase64: String,
                                     currentNotes: [String]) async -> (transcription: String?, notes: [String]) {
        do {
            var req = URLRequest(url: URL(string: "\(config.baseURL)/chat/completions")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = sideCallBody(config: config, imageBase64: imageBase64, currentNotes: currentNotes)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return (nil, []) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let content = msg["content"] as? String
            else { return (nil, []) }
            return parseSideResponse(content)
        } catch {
            return (nil, [])
        }
    }

    /// Background notes compaction (fire-and-forget). Returns nil on any failure
    /// so the caller leaves the notes list untouched.
    public func compactNotes(_ notes: [String]) async -> [String]? {
        do {
            var req = URLRequest(url: URL(string: "\(config.baseURL)/chat/completions")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = compactBody(config: config, notes: notes)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let content = msg["content"] as? String
            else { return nil }
            return parseCompactedNotes(content)
        } catch { return nil }
    }
}

public enum OracleError: Error { case http(Int), empty }
