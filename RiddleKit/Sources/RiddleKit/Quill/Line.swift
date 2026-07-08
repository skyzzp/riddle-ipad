import Foundation
import CoreGraphics
import CoreText

public struct Line { public var width: Int; public var height: Int; public var mask: [Bool] }

public enum QuillFont {
    /// Load a bundled TTF (RiddleKit resource) at a pixel size, Helvetica on failure.
    private static func bundled(_ name: String, px: CGFloat) -> CTFont {
        guard let url = Bundle.module.url(forResource: name, withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let cg = CGFont(provider) else {
            return CTFontCreateWithName("Helvetica" as CFString, px, nil)
        }
        return CTFontCreateWithGraphicsFont(cg, px, nil, nil)
    }

    /// Tom's hand: Aquiline Two (Manfred Klein, free) — a thin, spiky calligraphic
    /// cursive with long tapering terminals that matches the film diary's writing.
    public static func tomHand(px: CGFloat) -> CTFont { bundled("AquilineTwo", px: px) }
}

/// Rasterize one line via CoreText into a boolean ink mask (replaces ab_glyph).
/// Inked where drawn pixels are dark (coverage > 0.5). Origin: row 0 = top.
public func rasterizeLine(_ font: CTFont, _ text: String, _ px: CGFloat) -> Line {
    let attrs: [NSAttributedString.Key: Any] = [ kCTFontAttributeName as NSAttributedString.Key: font,
                  kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1) ]
    let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let adv = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
    let width = max(1, Int(adv.rounded(.up)) + 4)
    let height = max(1, Int((ascent + descent).rounded(.up)) + 4)
    let cs = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width, space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        return Line(width: width, height: height, mask: [Bool](repeating: false, count: width*height))
    }
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.textPosition = CGPoint(x: 2, y: descent + 2)
    CTLineDraw(ctLine, ctx)
    guard let data = ctx.data else {
        return Line(width: width, height: height, mask: [Bool](repeating: false, count: width*height))
    }
    let buf = data.bindMemory(to: UInt8.self, capacity: width*height)
    var mask = [Bool](repeating: false, count: width*height)
    for i in 0..<(width*height) { mask[i] = buf[i] < 128 }
    return Line(width: width, height: height, mask: mask)
}

/// Advance width of text (no rasterization). Port of script.rs::measure.
public func measure(_ font: CTFont, _ text: String) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [ kCTFontAttributeName as NSAttributedString.Key: font ]
    let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    return CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
}
