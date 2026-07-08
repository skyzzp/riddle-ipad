import Foundation
import CoreGraphics
import CoreText

public struct WritePlan {
    public var strokes: [[CGPoint]]
    public var nextY: CGFloat
    public var bounds: CGRect
}

/// Line advance for the reply. Based on the font's point size (not its full
/// ascent+descent, which is generous for a flourishy hand like Aquiline) so lines
/// sit close like real cursive — ascender/descender flourishes may gently interleave.
public func quillLineHeight(_ font: CTFont, px: CGFloat) -> CGFloat {
    CTFontGetSize(font) * 1.4
}

/// Lay out reply text into device-space centerline strokes. `yStart` continues a
/// streamed reply below its previous chunk; nil places the first chunk in the
/// upper third. Port of main.rs::plan_reply (centering, per-line wobble, LCG).
public func planReply(font: CTFont, text: String, px: CGFloat,
                      pageWidth: CGFloat, pageHeight: CGFloat, yStart: CGFloat?) -> WritePlan {
    let marginX = pageWidth * (120.0 / 1680.0)
    let maxW = pageWidth - 2 * marginX
    let lines = wrap(font, text, px: px, maxPx: maxW)
    let lineH = quillLineHeight(font, px: px)
    let totalH = lineH * CGFloat(lines.count)
    // Upper-third start, but for a tall reply shift up so it can't overrun the
    // bottom (leave a 60px bottom margin).
    var y = yStart ?? max(60, min((pageHeight - totalH) / 3, pageHeight - totalH - 60))
    var strokes: [[CGPoint]] = []
    var bounds = CGRect.null
    var seed: UInt32 = 0x1234
    func jitter() -> CGFloat {
        seed = seed &* 1664525 &+ 1013904223
        return CGFloat(Int((seed >> 16) % 7) - 3)
    }
    for lineText in lines {
        var raster = rasterizeLine(font, lineText, px)
        thin(&raster)
        let lineStrokes = trace(raster)
        let x0 = (pageWidth - CGFloat(raster.width)) / 2
        let wobble = jitter()
        for s in lineStrokes {
            let mapped = s.map { CGPoint(x: x0 + CGFloat($0.0), y: y + CGFloat($0.1) + wobble) }
            for pt in mapped { bounds = bounds.union(CGRect(x: pt.x, y: pt.y, width: 1, height: 1)) }
            strokes.append(mapped)
        }
        y += lineH
    }
    return WritePlan(strokes: strokes, nextY: y, bounds: bounds.isNull ? .zero : bounds)
}

public struct ReplyFit {
    public var font: CTFont
    public var px: CGFloat
    public var yStart: CGFloat
    public var scale: CGFloat
}

/// Size a full (buffered) reply so every sentence — each wrapped independently
/// and stacked at line height px*1.55, exactly as the quill writes them — fits
/// `pageHeight` minus top+bottom margins. Tries scale 1.0 downward in 0.05 steps;
/// at scale 1 the result is identical to the un-fitted layout, so short replies
/// are unchanged and only long ones shrink. `yStart` keeps the block in the upper
/// third but nudges it up so a tall reply keeps its bottom margin.
public func fitReply(sentences: [String], baseFontPx: CGFloat, basePx: CGFloat,
                     pageWidth: CGFloat, pageHeight: CGFloat,
                     topMargin: CGFloat = 60, bottomMargin: CGFloat = 60,
                     minScale: CGFloat = 0.5) -> ReplyFit {
    let marginX = pageWidth * (120.0 / 1680.0)
    let maxW = pageWidth - 2 * marginX
    let usableH = max(1, pageHeight - topMargin - bottomMargin)

    func lineCount(_ f: CTFont, _ px: CGFloat) -> Int {
        var n = 0
        for sentence in sentences { n += wrap(f, sentence, px: px, maxPx: maxW).count }
        return n
    }

    /// Nominal block height (baseline-advance grid): N lines × lineH. Used only
    /// for the unchanged upper-third start of short replies.
    func totalHeight(_ s: CGFloat) -> CGFloat {
        let f = QuillFont.tomHand(px: baseFontPx * s)
        let px = basePx * s
        return CGFloat(lineCount(f, px)) * quillLineHeight(f, px: px)
    }

    /// True rendered extent from the first line's image top (= yStart) to the LAST
    /// line's descenders. QuillWriter.renderLine puts each baseline topPad(0.65·fs)
    /// +ascent below its image top and descenders +descent lower; because
    /// AquilineTwo's nominal ascent is ~2.1·fs, the final line reaches far more than
    /// one lineH below its slot. Budgeting only N·lineH (as before) let a tall reply
    /// run its last words off the bottom — reserve the real extent instead. topPad
    /// mirrors QuillWriter.renderLine's 0.65·fs.
    func blockHeight(_ s: CGFloat) -> CGFloat {
        let f = QuillFont.tomHand(px: baseFontPx * s)
        let px = basePx * s
        let fs = CTFontGetSize(f)
        let lastExtent = 0.65 * fs + CTFontGetAscent(f) + CTFontGetDescent(f)
        return CGFloat(max(0, lineCount(f, px) - 1)) * quillLineHeight(f, px: px) + lastExtent
    }

    var s: CGFloat = 1.0
    while s > minScale && blockHeight(s) > usableH { s -= 0.05 }
    s = max(minScale, s)

    let font = QuillFont.tomHand(px: baseFontPx * s)
    let px = basePx * s
    let totalH = totalHeight(s)
    let blockH = blockHeight(s)
    // Short replies keep their exact upper-third start; a tall reply is lifted only
    // as far as needed to keep its true last-line bottom within the bottom margin.
    let yStart = max(topMargin, min((pageHeight - totalH) / 3, pageHeight - blockH - bottomMargin))
    return ReplyFit(font: font, px: px, yStart: yStart, scale: s)
}
