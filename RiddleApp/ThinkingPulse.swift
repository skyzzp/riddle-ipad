import UIKit
import RiddleKit

/// A subtle ink-blot that pulses at the page centre while Tom is "considering"
/// (the reply is in flight past the drink). Mirrors the Rust 600ms blot toggle.
@MainActor
final class ThinkingPulse {
    private let host: CALayer
    private let blot = CALayer()

    init(on host: CALayer) {
        self.host = host
    }

    func start() {
        let r: CGFloat = 9
        blot.backgroundColor = Theme.inkUIColor.cgColor
        blot.cornerRadius = r
        blot.frame = CGRect(x: host.bounds.midX - r, y: host.bounds.midY - r, width: 2*r, height: 2*r)
        blot.opacity = 0.15
        host.addSublayer(blot)
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0.15; a.toValue = 0.6
        a.duration = 0.6
        a.autoreverses = true
        a.repeatCount = .infinity
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        blot.add(a, forKey: "pulse")
    }

    func stop() {
        blot.removeAllAnimations()
        blot.removeFromSuperlayer()
    }
}
