import UIKit
import Metal
import MetalKit

/// Evaporates the ink in an OPAQUE ink-on-page-colour snapshot: dark ink pixels
/// fade smoothly and uniformly into the page colour (see Dissolve.metal).
/// The view exactly overlays the cream page, so at progress=1 it IS the page.
final class DissolveView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    var pageColor: UIColor = Theme.creamUIColor
    /// Fade curve: 0 linear, 1 smooth, 2 ease-in, 3 ease-out, 4 hold->vanish (see Dissolve.metal).
    /// Default 4: her ink holds dark, then drinks away near the end.
    var easeMode: Int32 = 4
    /// Per-pixel start-time spread, 0..~0.8. 0 = the whole mark fades as one.
    /// Default 0.7: the ink drinks unevenly/organically (each pixel still fades smoothly).
    var stagger: Float = 0.7
    private let device: MTLDevice?
    private let queue: MTLCommandQueue?
    private let pipeline: MTLComputePipelineState?
    private var srcTex: MTLTexture?
    private var displayLink: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var duration: TimeInterval = 1
    private var onDone: (() -> Void)?

    override init(frame: CGRect) {
        let dev = MTLCreateSystemDefaultDevice()
        device = dev
        queue = dev?.makeCommandQueue()
        if let dev,
           let lib = try? dev.makeDefaultLibrary(bundle: .main),
           let fn = lib.makeFunction(name: "dissolve"),
           let ps = try? dev.makeComputePipelineState(function: fn) {
            pipeline = ps
        } else { pipeline = nil }
        super.init(frame: frame)
        if let dev { metalLayer.device = dev }
        metalLayer.pixelFormat = .rgba8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = true
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Animate the ink evaporating to `pageColor`. If Metal is unavailable, calls
    /// completion immediately.
    func dissolve(image: UIImage, duration: TimeInterval, completion: @escaping () -> Void) {
        guard device != nil, queue != nil, pipeline != nil, let cg = image.cgImage,
              let loaderDevice = device else { completion(); return }
        // MTKTextureLoader rejects wide-gamut / extended-range CGImages — PencilKit
        // renders her ink in Display-P3 (RGBA16), unlike the flat-sRGB quill — which
        // made the drink silently bail and her ink "just disappear". Redraw into
        // plain 8-bit sRGB so any source image loads.
        let srcCG = Self.normalizedForMetal(cg) ?? cg
        let loader = MTKTextureLoader(device: loaderDevice)
        srcTex = try? loader.newTexture(cgImage: srcCG, options: [.SRGB: false])
        guard srcTex != nil else { completion(); return }
        metalLayer.drawableSize = CGSize(width: srcCG.width, height: srcCG.height)
        self.duration = duration; self.onDone = completion; self.start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Redraw into a guaranteed 8-bit sRGB context so MTKTextureLoader accepts it;
    /// it rejects extended-range / 16-bit CGImages (e.g. PencilKit's Display-P3 output).
    private static func normalizedForMetal(_ cg: CGImage) -> CGImage? {
        let w = cg.width, h = cg.height
        guard w > 0, h > 0,
              let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    @objc private func step() {
        let t = min(1, (CACurrentMediaTime() - start) / duration)
        render(progress: Float(t))
        if t >= 1 { displayLink?.invalidate(); displayLink = nil; onDone?(); onDone = nil }
    }

    private func render(progress: Float) {
        guard let queue, let pipeline, let src = srcTex,
              let drawable = metalLayer.nextDrawable(),
              let cmd = queue.makeCommandBuffer(), let enc = cmd.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(pipeline)
        enc.setTexture(src, index: 0)
        enc.setTexture(drawable.texture, index: 1)
        var p = progress
        enc.setBytes(&p, length: MemoryLayout<Float>.size, index: 0)
        var page = pageColor.simd4
        enc.setBytes(&page, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
        var mode = easeMode
        enc.setBytes(&mode, length: MemoryLayout<Int32>.size, index: 2)
        var stag = stagger
        enc.setBytes(&stag, length: MemoryLayout<Float>.size, index: 3)
        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let grid = MTLSize(width: (src.width + 15)/16, height: (src.height + 15)/16, depth: 1)
        enc.dispatchThreadgroups(grid, threadsPerThreadgroup: tg)
        enc.endEncoding()
        cmd.present(drawable); cmd.commit()
    }
}

private extension UIColor {
    var simd4: SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}
