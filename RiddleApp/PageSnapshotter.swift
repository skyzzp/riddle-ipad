import UIKit
import PencilKit
import RiddleKit

/// Renders her handwriting to a clean near-black-ink-on-WHITE PNG for the model —
/// decoupled from the cream/leather page styling, which is never transmitted.
enum PageSnapshotter {
    static func snapshotPNG(_ drawing: PKDrawing, canvasSize: CGSize, scale: CGFloat,
                            targetLongEdge: Int = 2048) -> Data? {
        let bounds = drawing.bounds
        guard !bounds.isNull, bounds.width > 1, bounds.height > 1 else { return nil }
        let margin: CGFloat = 20
        let rect = bounds.insetBy(dx: -margin, dy: -margin)

        // 1) Rasterize the ink at device scale as black-on-white.
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: fmt)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: rect.size))
            let img = drawing.image(from: rect, scale: scale)
            img.draw(at: .zero)
        }

        // 2) Pull an 8-bit grayscale buffer out of the CGImage.
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var gray = [UInt8](repeating: 255, count: w * h)
        let cs = CGColorSpaceCreateDeviceGray()
        guard let bmp = CGContext(data: &gray, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        bmp.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // 3) Downscale to the long-edge cap (RiddleKit).
        let ds = boxDownscaleGray(gray, width: w, height: h, targetLongEdge: targetLongEdge)

        // 4) Re-wrap as a grayscale PNG.
        guard let outCtx = CGContext(data: nil, width: ds.width, height: ds.height,
                                     bitsPerComponent: 8, bytesPerRow: ds.width, space: cs,
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        outCtx.data?.copyMemory(fromBytes: ds.pixels, count: ds.pixels.count)
        guard let outImg = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: outImg).pngData()
    }
}

private extension UnsafeMutableRawPointer {
    /// Copy a [UInt8] into this raw buffer.
    func copyMemory(fromBytes bytes: [UInt8], count: Int) {
        bytes.withUnsafeBytes { self.copyMemory(from: $0.baseAddress!, byteCount: count) }
    }
}
