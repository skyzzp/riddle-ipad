import Foundation

/// Strip common markdown so it never reaches the quill (a model once emitted
/// `*asterisks*`). Inline emphasis/code markers are removed; leading block
/// markers (heading/quote/list) are trimmed.
public func stripMarkdown(_ s: String) -> String {
    var t = s
    for m in ["**", "__", "~~", "*", "_", "`"] {
        t = t.replacingOccurrences(of: m, with: "")
    }
    t = t.replacingOccurrences(of: #"^\s*[#>\-\+\*]+\s+"#, with: "", options: .regularExpression)
    return t
}

/// The in-character failure line, or nil to fade quietly. A bare timeout is
/// silent (a waiting page); everything else "blurs" in Tom's voice.
public func inCharacterError(for error: Error?) -> String? {
    if let u = error as? URLError, u.code == .timedOut { return nil }
    return "the ink blurred and would not settle…"
}
