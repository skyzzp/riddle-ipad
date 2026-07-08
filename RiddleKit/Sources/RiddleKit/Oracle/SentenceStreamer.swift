import Foundation

/// Accumulates streamed fragments and emits each newly-completed sentence,
/// cleaned. Mirrors HttpOracle::ask's `acc`/`delivered` loop (oracle.rs).
public struct SentenceStreamer {
    private var acc = ""
    private var delivered = 0   // UTF-8 byte offset already emitted

    public init() {}

    /// Append a fragment; return any newly completed sentence chunk(s), cleaned.
    public mutating func push(_ fragment: String) -> [String] {
        guard !fragment.isEmpty else { return [] }
        acc += fragment
        guard let cut = sentenceCut(acc, from: delivered) else { return [] }
        let bytes = Array(acc.utf8)
        let chunk = String(decoding: bytes[delivered..<cut], as: UTF8.self)
        delivered = cut
        let cleaned = cleanChunk(chunk)
        return cleaned.isEmpty ? [] : [cleaned]
    }

    /// Emit any trailing text past the last sentence break (call at stream end).
    public mutating func flush() -> String? {
        let bytes = Array(acc.utf8)
        guard delivered < bytes.count else { return nil }
        let rest = String(decoding: bytes[delivered...], as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        delivered = bytes.count
        return rest.isEmpty ? nil : cleanChunk(rest)
    }
}
