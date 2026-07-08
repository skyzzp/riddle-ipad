import XCTest
@testable import RiddleKit

final class DiaryStateTests: XCTestCase {
    func testIsMidTurn() {
        XCTAssertFalse(DiaryState.listening.isMidTurn)
        for s in [DiaryState.drinking, .thinking, .replying, .lingering, .fadingReply] {
            XCTAssertTrue(s.isMidTurn)
        }
    }
    func testForwardCycleLegal() {
        XCTAssertTrue(DiaryState.listening.canTransition(to: .drinking))
        XCTAssertTrue(DiaryState.drinking.canTransition(to: .thinking))
        XCTAssertTrue(DiaryState.thinking.canTransition(to: .replying))
        XCTAssertTrue(DiaryState.replying.canTransition(to: .lingering))
        XCTAssertTrue(DiaryState.lingering.canTransition(to: .fadingReply))
        XCTAssertTrue(DiaryState.fadingReply.canTransition(to: .listening))
    }
    func testAbortToListeningAlwaysLegal() {
        for s in [DiaryState.drinking, .thinking, .replying, .lingering, .fadingReply] {
            XCTAssertTrue(s.canTransition(to: .listening))
        }
    }
    func testRecoveryEntriesFromListening() {
        XCTAssertTrue(DiaryState.listening.canTransition(to: .thinking))   // re-issue a persisted turn
        XCTAssertTrue(DiaryState.listening.canTransition(to: .replying))   // snap a buffered reply
    }
    func testIllegalJumpsRejected() {
        XCTAssertFalse(DiaryState.listening.canTransition(to: .fadingReply))
        XCTAssertFalse(DiaryState.drinking.canTransition(to: .replying))
        XCTAssertFalse(DiaryState.thinking.canTransition(to: .lingering))
        XCTAssertFalse(DiaryState.replying.canTransition(to: .drinking))
        XCTAssertFalse(DiaryState.fadingReply.canTransition(to: .replying))
    }
}
