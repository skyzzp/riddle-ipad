import XCTest
@testable import RiddleKit

final class IdleCommitTests: XCTestCase {
    func testCommitsAfterIdleWithInk() {
        XCTAssertTrue(shouldCommit(penDown: false, sinceLastTouch: 2.8, hasInk: true))
        XCTAssertTrue(shouldCommit(penDown: false, sinceLastTouch: 3.0, hasInk: true))
    }
    func testDoesNotCommitWhilePenDown() {
        XCTAssertFalse(shouldCommit(penDown: true, sinceLastTouch: 5.0, hasInk: true))
    }
    func testDoesNotCommitBeforeIdle() {
        XCTAssertFalse(shouldCommit(penDown: false, sinceLastTouch: 2.79, hasInk: true))
    }
    func testDoesNotCommitWithNoInk() {
        XCTAssertFalse(shouldCommit(penDown: false, sinceLastTouch: 10, hasInk: false))
    }
}
