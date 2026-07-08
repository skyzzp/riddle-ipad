import Foundation
import RiddleKit

/// Tiny on-disk box for the single in-flight turn, so a hard kill mid-turn can
/// be recovered on next launch (see recoveryAction).
enum PendingStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("riddle-pending.json")
    }
    static func save(_ p: PendingTurn) {
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: url, options: .atomic) }
    }
    static func load() -> PendingTurn? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PendingTurn.self, from: data)
    }
    static func clear() { try? FileManager.default.removeItem(at: url) }
}
