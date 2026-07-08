import SwiftUI
import PencilKit
import CoreImage
import RiddleKit

/// The diary surface: a full-bleed aged, wrinkled, wood-pulp-grained page. Hosts the
/// PencilKit canvas (her ink), a CALayer for the quill's output, and a UIView for the
/// dissolve overlay. Styling is display-only (never transmitted).
final class PageContainerView: UIView {
    let canvas = PKCanvasView()
    let overlayHost = CALayer()      // Tom's quill strokes (Stage 4)
    let dissolveHost = UIView()      // dissolve overlay mount (Stage 5)

    /// The composed page surface (aged tone + wrinkle relief + fibre grain) as an
    /// image, so the drink/reply dissolves composite over the REAL page, not a flat
    /// colour (otherwise the page flashes flat mid-dissolve).
    private(set) var pageSurface: UIImage?

    private let page = CALayer()

    static let agedBaseUI = UIColor(red: 0xE8/255.0, green: 0xD7/255.0, blue: 0xB0/255.0, alpha: 1)
    private static let wrinkleStrength: CGFloat = 0.22   // soft wrinkle relief
    private static let grainStrength:   CGFloat = 0.85   // wood-pulp / cotton fibre tooth

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .light   // stop PencilKit inverting dark ink in dark mode
        backgroundColor = Self.agedBaseUI

        page.backgroundColor = Self.agedBaseUI.cgColor
        page.contentsGravity = .resize
        layer.addSublayer(page)

        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly
        canvas.tool = PKInkingTool(.pen, color: Theme.inkUIColor, width: 6)
        addSubview(canvas)

        overlayHost.isGeometryFlipped = false
        layer.addSublayer(overlayHost)

        dissolveHost.isUserInteractionEnabled = false
        dissolveHost.backgroundColor = .clear
        addSubview(dissolveHost)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        page.frame = bounds
        canvas.frame = bounds
        overlayHost.frame = bounds
        dissolveHost.frame = bounds
        if page.contents == nil, bounds.width > 0 {
            let s = UIScreen.main.scale
            page.contentsScale = s
            let baked = Self.bakedPage(size: bounds.size, seed: 7)
            page.contents = baked
            pageSurface = baked.map { UIImage(cgImage: $0, scale: s, orientation: .up) }
        }
    }

    /// The bundled wrinkled-paper photo, desaturated and recentered to mid-gray so a
    /// soft-light blend contributes only crease highlights/shadows (relief), never a
    /// colour or brightness shift. Computed once. (CC-BY-2.0, see TEXTURE-CREDITS.txt.)
    private static let wrinkleCache: CGImage? = {
        guard let url = Bundle.main.url(forResource: "wrinkle", withExtension: "jpg"),
              let src = CIImage(contentsOf: url) else { return nil }
        let ctx = CIContext(options: nil)
        let cs = CGColorSpaceCreateDeviceRGB()
        let gray = src.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0])
        // Soften the sharp crumple into gentle undulation (handled paper, not a ball).
        let soft = gray.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4.0])
            .cropped(to: gray.extent)
        // Measure mean luminance so we can recenter it to 0.5.
        let avg = soft.applyingFilter("CIAreaAverage",
            parameters: [kCIInputExtentKey: CIVector(cgRect: soft.extent)])
        var px: [UInt8] = [0, 0, 0, 0]
        ctx.render(avg, toBitmap: &px, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: cs)
        let mean = CGFloat(px[0]) / 255.0
        let relief = soft.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: 0.5 - mean,   // flats -> neutral gray (no-op under soft-light)
            kCIInputContrastKey: 1.0])           // keep creases gentle
        return ctx.createCGImage(relief, from: soft.extent)
    }()

    /// Warm, mottled, grainy aged paper — tone + stains + vignette + speckle,
    /// stains/vignette heavier toward the edges so the writing centre stays calm
    /// and legible (SPIKE — lit wrinkles still want a real bundled photo).
    private static func makeAgedPaper(size: CGSize, seed: UInt64) -> CGImage? {
        guard size.width > 2, size.height > 2 else { return nil }
        var rng = SeededRNG(seed: seed)
        let cs = CGColorSpaceCreateDeviceRGB()
        let cx = size.width / 2, cy = size.height / 2
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            agedBaseUI.setFill(); c.fill(rect)

            // Mottled brown foxing/stains — stronger toward the edges (calm centre).
            let blobs = max(24, Int(size.width * size.height / 12000))
            for _ in 0..<blobs {
                let x = rng.next01() * size.width, y = rng.next01() * size.height
                let r = 24 + rng.next01() * 100
                let dx = (x - cx) / cx, dy = (y - cy) / cy
                let edge = min(1, (dx * dx + dy * dy).squareRoot())
                let a = (0.02 + rng.next01() * 0.045) * (0.35 + 0.65 * edge)
                let stain = UIColor(red: 0x6b/255.0, green: 0x52/255.0, blue: 0x2c/255.0, alpha: a).cgColor
                let clear = UIColor(red: 0x6b/255.0, green: 0x52/255.0, blue: 0x2c/255.0, alpha: 0).cgColor
                if let g = CGGradient(colorsSpace: cs, colors: [stain, clear] as CFArray, locations: [0, 1]) {
                    c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                         endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
                }
            }

            // Warm vignette hugging the edges/corners.
            let vClear = UIColor(red: 0x3a/255.0, green: 0x2a/255.0, blue: 0x12/255.0, alpha: 0).cgColor
            let vDark  = UIColor(red: 0x3a/255.0, green: 0x2a/255.0, blue: 0x12/255.0, alpha: 0.16).cgColor
            if let vg = CGGradient(colorsSpace: cs, colors: [vClear, vDark] as CFArray, locations: [0.55, 1.0]) {
                let maxR = (cx * cx + cy * cy).squareRoot()
                c.drawRadialGradient(vg, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                                     endCenter: CGPoint(x: cx, y: cy), endRadius: maxR, options: [])
            }
            // (fibre grain + wrinkle relief are composited in bakedPage)
        }.cgImage
    }

    /// The finished page surface: aged tone/stains/vignette, with the real wrinkle
    /// relief (soft-light) and a fine wood-pulp/cotton fibre tooth (overlay noise)
    /// composited on top. One image — used for `page.contents` AND as the background
    /// the drink/reply dissolves evaporate into, so the page never flashes flat.
    private static func bakedPage(size: CGSize, seed: UInt64) -> CGImage? {
        guard let paperCG = makeAgedPaper(size: size, seed: seed) else { return nil }
        let ctx = CIContext(options: nil)
        let paper = CIImage(cgImage: paperCG)
        let ext = paper.extent
        var out = paper

        // 1. Wrinkle relief from the bundled photo (mid-gray-centred -> soft-light).
        if let wr = wrinkleCache {
            let wrImg = CIImage(cgImage: wr)
            let scale = max(ext.width / wrImg.extent.width, ext.height / wrImg.extent.height)
            let wrScaled = wrImg.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).cropped(to: ext)
            let lit = wrScaled.applyingFilter("CISoftLightBlendMode",
                parameters: [kCIInputBackgroundImageKey: out])
            out = out.applyingFilter("CIDissolveTransition",
                parameters: ["inputTargetImage": lit, "inputTime": wrinkleStrength])
        }

        // 2. Fine fibre tooth — desaturated high-frequency noise, gently blurred so
        //    it reads as pulp/cotton fibre rather than digital static, overlay-blended.
        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage {
            let fibre = noise
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 0.5])
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6])
                .cropped(to: ext)
            let toothed = fibre.applyingFilter("CIOverlayBlendMode",
                parameters: [kCIInputBackgroundImageKey: out])
            out = out.applyingFilter("CIDissolveTransition",
                parameters: ["inputTargetImage": toothed, "inputTime": grainStrength])
        }

        return ctx.createCGImage(out, from: ext) ?? paperCG
    }

}

/// Tiny deterministic PRNG so the paper texture is stable across launches (SPIKE).
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next01() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var x = state
        x ^= x >> 33; x = x &* 0xff51afd7ed558ccd; x ^= x >> 33
        return CGFloat(x >> 11) / CGFloat(UInt64(1) << 53)
    }
}

struct PageView: UIViewRepresentable {
    let memory: Memory
    let engineBox: EngineBox

    final class Coordinator {
        var container: PageContainerView?
        var ink: InkController?
        var engine: DiaryEngine?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PageContainerView {
        let v = PageContainerView()
        context.coordinator.container = v
        let ink = InkController()
        ink.attach(to: v)
        let engine = DiaryEngine(container: v, ink: ink, memory: memory)
        ink.onCommit = { [weak engine] in engine?.beginTurn() }
        context.coordinator.ink = ink
        context.coordinator.engine = engine
        engineBox.engine = engine
        // Recover an interrupted turn once the container has bounds (next runloop).
        DispatchQueue.main.async { [weak engine] in engine?.resumeIfPending() }
        return v
    }

    func updateUIView(_ uiView: PageContainerView, context: Context) {}
}

/// Keeps Tom's reply on the page until she taps it (or a long safety timeout),
/// then calls `onDismiss` once. Removes its own tap recognizer when it fires.
@MainActor
final class LingerDismiss: NSObject {
    private var callback: (() -> Void)?
    private weak var view: UIView?
    private var tap: UITapGestureRecognizer?
    private var timer: Timer?

    init(on view: UIView, timeout: TimeInterval, onDismiss: @escaping () -> Void) {
        super.init()
        self.view = view
        self.callback = onDismiss
        let t = UITapGestureRecognizer(target: self, action: #selector(fire))
        view.addGestureRecognizer(t)
        self.tap = t
        self.timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
    }

    @objc func fire() {
        guard let cb = callback else { return }
        callback = nil
        timer?.invalidate(); timer = nil
        if let tap, let view { view.removeGestureRecognizer(tap) }
        tap = nil
        cb()
    }
}
