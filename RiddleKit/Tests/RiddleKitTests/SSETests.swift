import XCTest
@testable import RiddleKit

final class SSETests: XCTestCase {
    func testDeltaExtraction() {
        XCTAssertEqual(sseDeltaContent(#"{"choices":[{"delta":{"content":"Hello"},"index":0}]}"#), "Hello")
        XCTAssertNil(sseDeltaContent(#"{"choices":[{"delta":{"role":"assistant"},"index":0}]}"#))
    }
    func testUnicodeAndEscapes() {
        XCTAssertEqual(sseDeltaContent(#"{"choices":[{"delta":{"content":"Déjà vu — oui"}}]}"#), "Déjà vu — oui")
        XCTAssertEqual(sseDeltaContent(#"{"choices":[{"delta":{"content":"line\nbreak"}}]}"#), "line\nbreak")
        XCTAssertEqual(jsonStrField(#"{"content":"café"}"#, "content"), "café")
    }
    func testClean() {
        XCTAssertEqual(cleanChunk("  \"hello\"  "), "hello")
        XCTAssertEqual(cleanChunk("plain"), "plain")
    }
    func testSentenceCut() {
        XCTAssertEqual(sentenceCut("Yes, Harry?", from: 0), 11)
        XCTAssertNil(sentenceCut("Yes, Harr", from: 0))
        XCTAssertEqual(sentenceCut("Hi. Bye.", from: 0), 8)
        XCTAssertEqual(sentenceCut("Hi. Bye.", from: 4), 8)
        XCTAssertNil(sentenceCut("Hi.", from: 0))
    }
    func testSentenceCutRejectsMidScalarOffset() {
        // "café." is bytes [63 61 66 C3 A9 2E]; the é occupies bytes 3–4, so
        // offset 4 is a UTF-8 continuation byte (mid-scalar) → nil.
        XCTAssertNil(sentenceCut("café.", from: 4))
        // a valid start still finds the sentence end (byte length 6).
        XCTAssertEqual(sentenceCut("café.", from: 0), 6)
    }
}
