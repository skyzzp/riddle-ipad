import Foundation
import CoreText

/// Word-wrap `text` to lines that fit `maxPx`. Port of script.rs::wrap.
public func wrap(_ font: CTFont, _ text: String, px: CGFloat, maxPx: CGFloat) -> [String] {
    var lines: [String] = []
    for para in text.split(separator: "\n", omittingEmptySubsequences: false) {
        var cur = ""
        for word in para.split(separator: " ", omittingEmptySubsequences: true) {
            let cand = cur.isEmpty ? String(word) : "\(cur) \(word)"
            if measure(font, cand) <= maxPx || cur.isEmpty {
                cur = cand
            } else {
                lines.append(cur); cur = String(word)
            }
        }
        if !cur.isEmpty { lines.append(cur) }
    }
    return lines
}
