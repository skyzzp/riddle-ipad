import UIKit
import PencilKit
import RiddleKit

/// Tracks pen-down / idle state via PencilKit's own tool-use delegate callbacks
/// (NOT a gesture recognizer — that jams UIKit's gesture arbitration), plus a
/// polling timer that fires the commit when the page has been idle >= 2.8s.
final class InkController: NSObject, PKCanvasViewDelegate {
    var onCommit: (() -> Void)?
    /// Set false during Drinking/Thinking/Replying/FadingReply so ink can't
    /// arm a commit while a reply is in flight.
    var isListening = true

    private(set) var penDown = false
    private var lastTouchEnded = Date()
    private var didCommit = false
    private weak var canvas: PKCanvasView?
    private var timer: Timer?

    func attach(to container: PageContainerView) {
        canvas = container.canvas
        container.canvas.delegate = self
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Re-arm after a reply cycle completes.
    func reset() { didCommit = false; lastTouchEnded = Date() }

    // PencilKit reports exactly when a drawing/erasing action starts and ends.
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        penDown = true
    }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        penDown = false
        lastTouchEnded = Date()
    }

    private func tick() {
        guard isListening, !didCommit else { return }
        let hasInk = !(canvas?.drawing.strokes.isEmpty ?? true)
        let idle = Date().timeIntervalSince(lastTouchEnded)
        if shouldCommit(penDown: penDown, sinceLastTouch: idle, hasInk: hasInk, idleCommit: 2.3) {
            didCommit = true
            onCommit?()
        }
    }

    deinit { timer?.invalidate() }
}
