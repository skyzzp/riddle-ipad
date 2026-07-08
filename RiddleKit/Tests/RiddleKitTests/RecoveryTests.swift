import XCTest
@testable import RiddleKit

final class RecoveryTests: XCTestCase {
    func testNoPendingIsNone() {
        XCTAssertEqual(recoveryAction(hasPending: false, replyBuffered: false, ageSeconds: 0), .none)
    }
    func testBufferedReplySnaps() {
        XCTAssertEqual(recoveryAction(hasPending: true, replyBuffered: true, ageSeconds: 5), .snap)
    }
    func testFreshUnansweredReissues() {
        XCTAssertEqual(recoveryAction(hasPending: true, replyBuffered: false, ageSeconds: 60), .reissue)
    }
    func testStaleUnansweredBlurs() {
        XCTAssertEqual(recoveryAction(hasPending: true, replyBuffered: false,
                                      ageSeconds: 3600, maxAgeSeconds: 1800), .blur)
    }
    func testPendingTurnCodable() throws {
        let p = PendingTurn(snapshotBase64: "AAAA",
                            timestamp: Date(timeIntervalSince1970: 10), reply: ["hi", "there"])
        let back = try JSONDecoder().decode(PendingTurn.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back, p)
    }
}
