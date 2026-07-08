import UIKit
import CoreText
import RiddleKit

/// Draws Tom's reply as the invisible quill. Each wrapped line is rendered as the
/// REAL Aquiline glyphs (full calligraphic weight, no clipped flourishes), then
/// *revealed by a pen tracing each letter's actual writing centerline*: a wide
/// stroked mask follows the ported raster→thin→trace polylines, animated by
/// strokeEnd, so the ink appears along the pen's path rather than as a flat wipe.
/// When a line finishes the mask is dropped, so any ink the centerline tube didn't
/// cover is still fully shown.
final class QuillWriter {
    private let host: CALayer
    private let font: CTFont
    private let pageSize: CGSize
    private let px: CGFloat
    private var nextY: CGFloat
    private let scale = UIScreen.main.scale

    init(host: CALayer, font: CTFont, pageSize: CGSize, px: CGFloat, yStart: CGFloat? = nil) {
        self.host = host; self.font = font; self.pageSize = pageSize; self.px = px
        self.nextY = yStart ?? pageSize.height / 3
    }

    func write(sentence: String, animated: Bool = true, completion: (() -> Void)? = nil) {
        let marginX = pageSize.width * (120.0 / 1680.0)
        let maxW = pageSize.width - 2 * marginX
        let lines = wrap(font, sentence, px: px, maxPx: maxW)
        guard !lines.isEmpty else { completion?(); return }
        writeLines(lines, 0, animated: animated, completion: completion)
    }

    private func writeLines(_ lines: [String], _ i: Int, animated: Bool, completion: (() -> Void)?) {
        guard i < lines.count else { completion?(); return }
        let lineH = quillLineHeight(font, px: px)
        func advance() { nextY += lineH; writeLines(lines, i + 1, animated: animated, completion: completion) }

        guard let r = Self.renderLine(lines[i], font: font, ink: Theme.inkUIColor, scale: scale) else {
            advance(); return
        }
        let layer = CALayer()
        layer.contents = r.image.cgImage
        layer.contentsScale = scale
        layer.frame = CGRect(x: (pageSize.width - r.size.width) / 2, y: nextY,
                             width: r.size.width, height: r.size.height)
        host.addSublayer(layer)

        // Build the pen path (all centerline strokes, in the image's coordinates).
        let path = CGMutablePath()
        for stroke in r.strokes {
            guard let first = stroke.first else { continue }
            path.move(to: first)
            for pt in stroke.dropFirst() { path.addLine(to: pt) }
        }

        guard animated, !path.isEmpty else { advance(); return }

        let mask = CAShapeLayer()
        mask.frame = layer.bounds
        mask.path = path
        mask.strokeColor = UIColor.white.cgColor
        mask.fillColor = UIColor.clear.cgColor
        mask.lineWidth = CTFontGetSize(font) * 0.24   // pen tube: wide enough to reveal thick strokes
        mask.lineCap = .round
        mask.lineJoin = .round
        mask.strokeEnd = 0
        layer.mask = mask

        // Ink-pen pace (unchanged feel), proportional to the inked width.
        let duration = max(1.1, Double(r.size.width) / 210.0)
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0; anim.toValue = 1
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards; anim.isRemovedOnCompletion = false
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layer.mask = nil   // reveal any ink the centerline tube didn't cover
            advance()
        }
        mask.add(anim, forKey: "trace")
        mask.strokeEnd = 1
        CATransaction.commit()
    }

    /// Remove all written strokes (used before the reply-fade / on reset).
    func clear() { host.sublayers?.forEach { $0.removeFromSuperlayer() }; nextY = pageSize.height / 3 }

    /// Render one line of Tom's hand to a weighted-glyph image (generous padding so
    /// flourishes aren't clipped) plus its centerline pen strokes, both in the same
    /// image-point coordinate space so the strokes can mask the image.
    private static func renderLine(_ text: String, font: CTFont, ink: UIColor,
                                   scale: CGFloat) -> (image: UIImage, size: CGSize, strokes: [[CGPoint]])? {
        let attrs = [kCTFontAttributeName: font,
                     kCTForegroundColorAttributeName: ink.cgColor] as CFDictionary
        guard let astr = CFAttributedStringCreate(nil, text as CFString, attrs) else { return nil }
        let line = CTLineCreateWithAttributedString(astr)
        let ib = CTLineGetImageBounds(line, nil)
        guard ib.width.isFinite, ib.height.isFinite, ib.width > 0 else { return nil }

        let fs = CTFontGetSize(font)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        let padX = fs * 0.30
        let topPad = fs * 0.65, botPad = fs * 0.55
        let w = max(1, ceil(ib.width) + 2 * padX)
        let h = ceil(topPad + ascent + descent + botPad)
        let drawX = padX - ib.minX
        let baseline = botPad + descent

        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = scale; fmt.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            let c = ctx.cgContext
            c.textMatrix = .identity
            c.translateBy(x: 0, y: h); c.scaleBy(x: 1, y: -1)   // flip into CoreText's y-up space
            c.textPosition = CGPoint(x: drawX, y: baseline)
            CTLineDraw(line, c)
        }

        // Centerline pen strokes via the ported raster→thin→trace, mapped into image
        // coordinates. rasterizeLine draws with pen origin x=2 and baseline at
        // (ascent+2) from the top; our image draws at drawX and (topPad+ascent).
        var raster = rasterizeLine(font, text, fs)
        thin(&raster)
        let traced = trace(raster)
        let dx = drawX - 2
        let dy = topPad - 2
        let strokes = traced.map { $0.map { CGPoint(x: CGFloat($0.0) + dx, y: CGFloat($0.1) + dy) } }

        return (image, CGSize(width: w, height: h), strokes)
    }
}
