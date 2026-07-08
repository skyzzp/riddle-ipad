import Foundation

/// A turn persisted at drink-time so it survives a hard kill. `reply` is nil
/// until the model answers; once set, cold launch can snap it without re-asking.
public struct PendingTurn: Codable, Equatable, Sendable {
    public var snapshotBase64: String
    public var timestamp: Date
    public var reply: [String]?
    public init(snapshotBase64: String, timestamp: Date, reply: [String]? = nil) {
        self.snapshotBase64 = snapshotBase64; self.timestamp = timestamp; self.reply = reply
    }
}

public enum RecoveryAction: Equatable { case none, snap, reissue, blur }

/// Decide what to do with an interrupted turn on cold launch (or foreground
/// after the assertion expired). "Snap, don't resume": a buffered reply is
/// rendered complete; an unanswered-but-recent turn is re-issued so Tom finishes
/// his thought; an unanswered-and-stale turn gets an in-character blur.
public func recoveryAction(hasPending: Bool, replyBuffered: Bool,
                           ageSeconds: TimeInterval,
                           maxAgeSeconds: TimeInterval = 1800) -> RecoveryAction {
    guard hasPending else { return .none }
    if replyBuffered { return .snap }
    if ageSeconds <= maxAgeSeconds { return .reissue }
    return .blur
}
