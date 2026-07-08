import XCTest
import CoreText
@testable import RiddleKit

final class FitReplyTests: XCTestCase {
    // A short reply fits at full size (scale unchanged).
    func testShortReplyKeepsFullScale() {
        let fit = fitReply(sentences: ["It is a pleasure to meet you."],
                           baseFontPx: 96, basePx: 50,
                           pageWidth: 970, pageHeight: 1322)
        XCTAssertEqual(fit.scale, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(fit.yStart, 60)
    }

    // A very long reply is shrunk below full size and still keeps a top margin.
    func testLongReplyShrinksToFit() {
        let long = Array(repeating: "This is a fairly long sentence that will wrap across the page several times over and over.", count: 14)
        let fit = fitReply(sentences: long,
                           baseFontPx: 96, basePx: 50,
                           pageWidth: 970, pageHeight: 1322)
        XCTAssertLessThan(fit.scale, 1.0)
        XCTAssertGreaterThanOrEqual(fit.scale, 0.5)
        XCTAssertGreaterThanOrEqual(fit.yStart, 60)
    }

    /// The writer (QuillWriter.renderLine) places each line's baseline
    /// topPad(0.65·fs)+ascent below its image top (= yStart + i·lineH) and its
    /// descenders +descent lower. AquilineTwo's nominal ascent is ~2.1·fs, so the
    /// last line extends far more than one lineH below its slot. fitReply must
    /// reserve that real extent — a tall-but-scale-1-fitting reply used to run its
    /// last words off the bottom (memory-fed replies exposed it). Reconstruct the
    /// rendered bottom and assert it stays on the page.
    private func renderedBottom(_ fit: ReplyFit, _ sentences: [String],
                                pageWidth: CGFloat) -> CGFloat {
        let marginX = pageWidth * (120.0 / 1680.0)
        let maxW = pageWidth - 2 * marginX
        var lineCount = 0
        for s in sentences { lineCount += wrap(fit.font, s, px: fit.px, maxPx: maxW).count }
        let lineH = quillLineHeight(fit.font, px: fit.px)
        let fs = CTFontGetSize(fit.font)
        let lastExtent = 0.65 * fs + CTFontGetAscent(fit.font) + CTFontGetDescent(fit.font)
        return fit.yStart + CGFloat(max(0, lineCount - 1)) * lineH + lastExtent
    }

    func testTallReplyLastLineStaysOnPage() {
        let pageW: CGFloat = 1024, pageH: CGFloat = 1366
        // Nine one-line sentences: fits usableH at scale 1 by the old N·lineH
        // budget, but the last line's descenders ran ~26pt+ off the bottom.
        let sentences = (0..<9).map { "Short diary line number \($0)." }
        let fit = fitReply(sentences: sentences, baseFontPx: 96, basePx: 53,
                           pageWidth: pageW, pageHeight: pageH)
        XCTAssertLessThanOrEqual(renderedBottom(fit, sentences, pageWidth: pageW), pageH,
                                 "last line runs off the bottom of the page")
    }
}
