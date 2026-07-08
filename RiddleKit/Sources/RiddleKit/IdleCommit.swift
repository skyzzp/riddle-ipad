import Foundation

/// The original's commit condition (main.rs):
/// `!pen_down && last_pen.elapsed() >= IDLE_COMMIT && !user_ink.is_empty()`.
public func shouldCommit(penDown: Bool,
                         sinceLastTouch: TimeInterval,
                         hasInk: Bool,
                         idleCommit: TimeInterval = 2.8) -> Bool {
    !penDown && sinceLastTouch >= idleCommit && hasInk
}
