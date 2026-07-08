import Foundation

/// Extract a top-level string field's value (first match; unescaped incl \uXXXX).
/// Port of oracle.rs::json_str_field.
public func jsonStrField(_ s: String, _ key: String) -> String? {
    let pat = "\"\(key)\":\""
    guard let r = s.range(of: pat) else { return nil }
    var out = ""
    var it = s[r.upperBound...].makeIterator()
    while let c = it.next() {
        if c == "\\" {
            guard let n = it.next() else { break }
            switch n {
            case "n": out.append("\n"); case "t": out.append("\t"); case "r": out.append("\r")
            case "\"": out.append("\""); case "\\": out.append("\\"); case "/": out.append("/")
            case "u":
                var hex = ""
                for _ in 0..<4 { if let h = it.next() { hex.append(h) } }
                if let v = UInt32(hex, radix: 16), let sc = Unicode.Scalar(v) { out.append(Character(sc)) }
            default: out.append(n)
            }
        } else if c == "\"" { break } else { out.append(c) }
    }
    return out
}

/// Pull choices[0].delta.content out of one SSE data object. Port of sse_delta_content.
public func sseDeltaContent(_ s: String) -> String? {
    guard let d = s.range(of: "\"delta\"") else { return nil }
    return jsonStrField(String(s[d.lowerBound...]), "content")
}

/// Trim + strip stray wrapping quotes. Port of oracle.rs::clean.
public func cleanChunk(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("\"") { t.removeFirst() }
    if t.hasSuffix("\"") { t.removeLast() }
    return t
}

/// End (UTF-8 byte offset) of the LAST complete sentence after `from`: sentence
/// punctuation followed by whitespace or end-of-text, with end-from >= 4.
/// Port of oracle.rs::sentence_cut. Byte offsets match the original's semantics.
public func sentenceCut(_ text: String, from: Int) -> Int? {
    let bytes = Array(text.utf8)
    guard from <= bytes.count else { return nil }
    // Mirror Rust's `text.get(from..)?`: a `from` inside a multibyte scalar is invalid.
    if from < bytes.count && (bytes[from] & 0xC0) == 0x80 { return nil }
    let tail = String(decoding: bytes[from...], as: UTF8.self)
    var cut: Int? = nil
    var byteIdx = from
    for ch in tail {
        let isPunct = ch == "." || ch == "!" || ch == "?" || ch == "\u{2026}"
        let len = String(ch).utf8.count
        let end = byteIdx + len
        if isPunct {
            let after = String(decoding: bytes[end...], as: UTF8.self)
            let nextIsWSorEnd = after.first.map { $0.isWhitespace } ?? true
            if nextIsWSorEnd && (end - from) >= 4 { cut = end }
        }
        byteIdx = end
    }
    return cut
}
