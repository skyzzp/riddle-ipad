import XCTest
@testable import RiddleKit

final class SideCallTests: XCTestCase {
    func testParsesPlainJSON() {
        let (t, n) = parseSideResponse(#"{"transcription":"Hello Tom","notes":["her name is Luna"]}"#)
        XCTAssertEqual(t, "Hello Tom")
        XCTAssertEqual(n, ["her name is Luna"])
    }
    func testParsesFencedJSONWithProse() {
        let raw = """
        Sure, here is the JSON:
        ```json
        {"transcription": "I feel alone", "notes": ["she keeps returning to feeling alone"]}
        ```
        """
        let (t, n) = parseSideResponse(raw)
        XCTAssertEqual(t, "I feel alone")
        XCTAssertEqual(n, ["she keeps returning to feeling alone"])
    }
    func testEmptyTranscriptionBecomesNil() {
        let (t, n) = parseSideResponse(#"{"transcription":"","notes":[]}"#)
        XCTAssertNil(t)
        XCTAssertEqual(n, [])
    }
    func testMissingNotesFieldYieldsEmpty() {
        let (t, n) = parseSideResponse(#"{"transcription":"just words"}"#)
        XCTAssertEqual(t, "just words")
        XCTAssertEqual(n, [])
    }
    func testGarbageYieldsNilAndEmpty() {
        let (t, n) = parseSideResponse("the model refused and wrote prose only")
        XCTAssertNil(t)
        XCTAssertEqual(n, [])
    }
    func testBodyIsNonStreamingSideModel() throws {
        let cfg = OracleConfig(apiKey: "k", model: Persona.sideModel)
        let data = sideCallBody(config: cfg, imageBase64: "IMG", currentNotes: ["her name is Luna"])
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["stream"] as? Bool, false)
        XCTAssertEqual(obj?["model"] as? String, Persona.sideModel)
        // current notes are conveyed so the model won't re-extract them
        let msgs = obj?["messages"] as? [[String: Any]]
        let userParts = msgs?.last?["content"] as? [[String: Any]]
        let text = userParts?.first?["text"] as? String
        XCTAssertTrue(text?.contains("her name is Luna") ?? false)
    }

    func testParsesCompactedNotesArray() {
        let out = parseCompactedNotes(#"{"notes":["her name is Luna","she feels alone"]}"#)
        XCTAssertEqual(out, ["her name is Luna", "she feels alone"])
    }
    func testCompactedNotesFencedBareArray() {
        let out = parseCompactedNotes("```json\n[\"a\",\"b\"]\n```")
        XCTAssertEqual(out, ["a", "b"])
    }
    func testCompactedNotesGarbageIsNil() {
        XCTAssertNil(parseCompactedNotes("sorry, I can't"))
    }
    func testCompactBodyIsTextOnlyNoImage() throws {
        let data = compactBody(config: OracleConfig(apiKey: "k", model: Persona.sideModel),
                               notes: ["a", "b"])
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let msgs = obj?["messages"] as? [[String: Any]]
        // user content is a plain string (no image parts)
        XCTAssertTrue(msgs?.last?["content"] is String)
    }
}
