import Foundation
import RiddleKit

/// On-device persistence for Tom's memory. Loads at launch, writes on every
/// turn commit (so a hard kill loses at most the single in-flight turn).
@MainActor
final class Memory {
    private(set) var store: MemoryStore
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("riddle-memory.json")
        if let data = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode(MemoryStore.self, from: data) {
            store = s
        } else {
            store = MemoryStore()
        }
    }

    func commit(turn: Turn) { store.appendTurn(turn); save() }
    func setHerText(_ text: String, forTurnAt ts: Date) { store.setHerText(text, forTurnAt: ts); save() }
    func applyNotes(_ notes: [String]) { store.appendNotes(notes); save() }

    /// The wipe ritual (Settings): Tom a blank-slate stranger again.
    func wipe() {
        store = MemoryStore()
        try? FileManager.default.removeItem(at: url)
    }

    /// Replace the notes list wholesale (used by compaction).
    func replaceNotes(_ notes: [String]) { store.notes = notes; save() }
    var needsCompaction: Bool { store.needsCompaction }

    private func save() {
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
