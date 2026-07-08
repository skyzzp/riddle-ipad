import Foundation

/// One captured turn. `herText` is filled asynchronously by the side-call and
/// may be nil (transcription not landed / failed) — the assembler drops a nil
/// user line rather than stalling.
public struct Turn: Codable, Equatable, Sendable {
    public var herText: String?
    public var tomReply: String
    public var timestamp: Date
    public init(herText: String?, tomReply: String, timestamp: Date) {
        self.herText = herText; self.tomReply = tomReply; self.timestamp = timestamp
    }
}

/// The persistent two-tier memory: a verbatim ring of the last K turns plus a
/// flat notes list. The notes list carries both hard facts and soft
/// observations (the spec folds the rolling summary into it). Dedup/merge is
/// deferred to compaction; append does only a cheap exact-dup guard.
public struct MemoryStore: Codable, Equatable, Sendable {
    public var notes: [String]
    public var ring: [Turn]

    public static let ringSize = 8
    public static let compactionThreshold = 40

    public init(notes: [String] = [], ring: [Turn] = []) {
        self.notes = notes; self.ring = ring
    }

    /// Append a completed turn, evicting the oldest so the ring holds ≤ K.
    public mutating func appendTurn(_ turn: Turn) {
        ring.append(turn)
        if ring.count > Self.ringSize { ring.removeFirst(ring.count - Self.ringSize) }
    }

    /// Append newly-extracted notes (skip blanks + exact dupes already present).
    public mutating func appendNotes(_ new: [String]) {
        for n in new {
            let t = n.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && !notes.contains(n) { notes.append(n) }
        }
    }

    /// Backfill a turn's transcription once the side-call lands (matched by the
    /// turn's timestamp, so a fast next-turn can't clobber the wrong record).
    public mutating func setHerText(_ text: String, forTurnAt timestamp: Date) {
        if let i = ring.lastIndex(where: { $0.timestamp == timestamp }) {
            ring[i].herText = text
        }
    }

    public var needsCompaction: Bool { notes.count > Self.compactionThreshold }
}
