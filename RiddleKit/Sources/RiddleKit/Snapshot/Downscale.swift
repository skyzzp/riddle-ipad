import Foundation

/// Box-average downscale of a row-major 8-bit grayscale buffer so the long edge
/// stays <= targetLongEdge. Integer factor, never upscales. Port of ink.rs::to_png.
public func boxDownscaleGray(_ src: [UInt8], width: Int, height: Int,
                             targetLongEdge: Int) -> (pixels: [UInt8], width: Int, height: Int) {
    precondition(src.count == width * height, "buffer size mismatch")
    let f = max(1, (max(width, height) + targetLongEdge - 1) / targetLongEdge)
    if f == 1 { return (src, width, height) }
    let w = width / f, h = height / f
    var out = [UInt8](repeating: 0, count: w * h)
    for oy in 0..<h {
        for ox in 0..<w {
            var acc = 0
            for sy in 0..<f {
                for sx in 0..<f {
                    acc += Int(src[(oy*f + sy) * width + (ox*f + sx)])
                }
            }
            out[oy*w + ox] = UInt8(acc / (f*f))
        }
    }
    return (out, w, h)
}
