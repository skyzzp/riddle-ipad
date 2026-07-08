import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}
let Sf = CGFloat(S)
var seed: UInt64 = 0x2b1d
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1; var x = seed; x ^= x>>33; x = x &* 0xff51afd7ed558ccd; x ^= x>>33; return CGFloat(x>>11)/CGFloat(UInt64(1)<<53) }
func radial(_ c0: CGColor, _ c1: CGColor, cx: CGFloat, cy: CGFloat, r: CGFloat, after: Bool = false) {
    let g = CGGradient(colorsSpace: cs, colors: [c0, c1] as CFArray, locations: [0,1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: after ? [.drawsAfterEndLocation] : [])
}

// 1. Near-black worn leather base with a faint warm spotlight.
radial(rgb(0x1C,0x16,0x11), rgb(0x07,0x05,0x03), cx: Sf/2, cy: Sf*0.56, r: Sf*0.78, after: true)

// 2. Worn leather mottling — big soft dark/light patches.
for _ in 0..<44 {
    let x = rnd()*Sf, y = rnd()*Sf, r = 70 + rnd()*160
    let light = rnd() < 0.45
    let a = 0.05 + rnd()*0.06
    radial(light ? rgb(0x33,0x2a,0x1e, a) : rgb(0,0,0, a),
           light ? rgb(0x33,0x2a,0x1e, 0) : rgb(0,0,0, 0), cx: x, cy: y, r: r)
}

// 3. Fine leather grain speckle.
for _ in 0..<140000 {
    let x = rnd()*Sf, y = rnd()*Sf
    ctx.setFillColor(rnd() < 0.5 ? rgb(0,0,0, rnd()*0.10) : rgb(0x40,0x34,0x26, rnd()*0.08))
    ctx.fill(CGRect(x: x, y: y, width: 1.6, height: 1.6))
}

// 4. Soft diagonal sheen (upper-left grazing light).
radial(rgb(0x4a,0x3d,0x2c, 0.42), rgb(0x4a,0x3d,0x2c, 0), cx: Sf*0.33, cy: Sf*0.70, r: Sf*0.46)

// 5. Corner vignette for depth.
radial(rgb(0,0,0,0), rgb(0,0,0,0.5), cx: Sf/2, cy: Sf/2, r: Sf*0.72)

// 6. Warm rim-light along top + left edges.
let rim = CGGradient(colorsSpace: cs, colors: [rgb(0x5a,0x4a,0x36,0.55), rgb(0x5a,0x4a,0x36,0)] as CFArray, locations: [0,1])!
ctx.drawLinearGradient(rim, start: CGPoint(x: 0, y: Sf), end: CGPoint(x: 0, y: Sf-9), options: [])
ctx.drawLinearGradient(rim, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 9, y: 0), options: [])

// 7. Gilt "T. M. RIDDLE", embossed, centred on the full cover.
func drawName(_ dx: CGFloat, _ dy: CGFloat, _ color: CGColor) {
    let font = CTFontCreateWithName("Georgia-Bold" as CFString, 88, nil)
    let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color, kCTKernAttributeName: 9 as CFNumber] as CFDictionary
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, "T. M. RIDDLE" as CFString, attrs)!)
    let b = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: Sf/2 - b.width/2 - b.minX + dx, y: Sf*0.52 - b.height/2 + dy)
    CTLineDraw(line, ctx)
}
drawName(0, -3, rgb(0x08,0x05,0x03, 0.9))
drawName(0,  2, rgb(0xCF,0xB0,0x6a, 0.5))
drawName(0,  0, rgb(0xA6,0x87,0x49))

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "icon-1024.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
print("wrote icon-1024.png")
