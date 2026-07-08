import XCTest
@testable import RiddleKit

final class SentenceStreamerTests: XCTestCase {
    func testDeliversCompletedSentences() {
        var s = SentenceStreamer()
        XCTAssertEqual(s.push("Yes"), [])
        XCTAssertEqual(s.push(", Harry?"), ["Yes, Harry?"])
        XCTAssertEqual(s.push(" I re"), [])
        XCTAssertEqual(s.push("member."), ["I remember."])
        XCTAssertNil(s.flush())
    }
    func testFlushTrailing() {
        var s = SentenceStreamer()
        _ = s.push("A complete one. Then a dangling tail")
        XCTAssertEqual(s.flush(), "Then a dangling tail")
    }
}
