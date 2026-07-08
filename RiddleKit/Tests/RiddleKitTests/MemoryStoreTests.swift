import XCTest
@testable import RiddleKit

final class MemoryStoreTests: XCTestCase {
    private func turn(_ her: String?, _ tom: String, _ t: TimeInterval) -> Turn {
        Turn(herText: her, tomReply: tom, timestamp: Date(timeIntervalSince1970: t))
    }

    func testRingEvictsBeyondK() {
        var s = MemoryStore()
        for i in 0..<12 { s.appendTurn(turn("u\(i)", "t\(i)", TimeInterval(i))) }
        XCTAssertEqual(s.ring.count, MemoryStore.ringSize)          // 8
        XCTAssertEqual(s.ring.first?.tomReply, "t4")                // oldest four fell off
        XCTAssertEqual(s.ring.last?.tomReply, "t11")
    }

    func testAppendNotesSkipsExactDupesAndBlanks() {
        var s = MemoryStore()
        s.appendNotes(["her name is Luna", "  ", "her name is Luna", "she feels alone"])
        XCTAssertEqual(s.notes, ["her name is Luna", "she feels alone"])
    }

    func testSetHerTextBackfillsByTimestamp() {
        var s = MemoryStore()
        s.appendTurn(turn(nil, "I see the ink take shape.", 100))
        s.appendTurn(turn(nil, "Go on.", 200))
        s.setHerText("Hello Tom", forTurnAt: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(s.ring.first?.herText, "Hello Tom")
        XCTAssertNil(s.ring.last?.herText)                          // untouched
    }

    func testNeedsCompaction() {
        var s = MemoryStore()
        XCTAssertFalse(s.needsCompaction)
        s.notes = (0...40).map { "note \($0)" }                     // 41 > 40
        XCTAssertTrue(s.needsCompaction)
    }

    func testCodableRoundTrip() throws {
        var s = MemoryStore(notes: ["a"], ring: [turn("u", "t", 1)])
        s.appendTurn(turn(nil, "t2", 2))
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(MemoryStore.self, from: data)
        XCTAssertEqual(back, s)
    }
}
