import Foundation

/// The turn cycle, made explicit so the app can query "what phase am I in?"
/// (backgrounding) and so illegal jumps trip a precondition in the engine.
/// Deliberately carries NO associated data: unlike the Rust `enum State`
/// (a single-threaded tick loop that had nowhere else to keep stage/timers),
/// our structured-concurrency engine holds all per-phase data in locals.
public enum DiaryState: String, Equatable, Sendable {
    case listening, drinking, thinking, replying, lingering, fadingReply
}

public extension DiaryState {
    /// True whenever a turn is in flight. Stage 9 reads this to decide whether
    /// a background/foreground event must preserve or recover an interrupted turn.
    var isMidTurn: Bool { self != .listening }

    /// Legal edges: the forward cycle, plus (a) abort/finish to `.listening`
    /// from anywhere, and (b) recovery entries from `.listening` used on cold
    /// launch — `.thinking` (re-issue a persisted, unanswered turn) and
    /// `.replying` (snap a buffered-but-undrawn reply).
    func canTransition(to next: DiaryState) -> Bool {
        if next == .listening { return true }
        switch self {
        case .listening:   return next == .drinking || next == .thinking || next == .replying
        case .drinking:    return next == .thinking
        case .thinking:    return next == .replying
        case .replying:    return next == .lingering
        case .lingering:   return next == .fadingReply
        case .fadingReply: return false
        }
    }
}
