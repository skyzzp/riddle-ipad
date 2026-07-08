import XCTest
@testable import RiddleKit

final class ReplyAssemblyTests: XCTestCase {
    func testSystemCarriesNotesAndRingAlternates() {
        var store = MemoryStore(notes: ["her name is Luna"])
        store.appendTurn(Turn(herText: "Are you real?", tomReply: "As real as this ink.",
                              timestamp: Date(timeIntervalSince1970: 1)))
        let msgs = replyMessages(persona: "PERSONA", store: store,
                                 imageBase64: "AAAA", userText: "Reply.")
        // system + (user, assistant) + current user
        XCTAssertEqual(msgs.count, 4)
        let system = msgs[0]["content"] as? String
        XCTAssertEqual(msgs[0]["role"] as? String, "system")
        XCTAssertTrue(system?.hasPrefix("PERSONA") ?? false)
        XCTAssertTrue(system?.contains("her name is Luna") ?? false)
        XCTAssertEqual(msgs[1]["role"] as? String, "user")
        XCTAssertEqual(msgs[1]["content"] as? String, "Are you real?")
        XCTAssertEqual(msgs[2]["role"] as? String, "assistant")
        XCTAssertEqual(msgs[2]["content"] as? String, "As real as this ink.")
        // current page: array content with a text part + an image data-URI
        XCTAssertEqual(msgs[3]["role"] as? String, "user")
        let parts = msgs[3]["content"] as? [[String: Any]]
        XCTAssertEqual(parts?.count, 2)
        let url = ((parts?[1]["image_url"]) as? [String: Any])?["url"] as? String
        XCTAssertEqual(url, "data:image/png;base64,AAAA")
    }

    func testDropsUserLineWhenTranscriptionMissing() {
        var store = MemoryStore()
        store.appendTurn(Turn(herText: nil, tomReply: "The ink is faint tonight.",
                              timestamp: Date(timeIntervalSince1970: 2)))
        let msgs = replyMessages(persona: "P", store: store, imageBase64: "IMG", userText: "R")
        // system + assistant-only (no user for the missing transcription) + current user
        XCTAssertEqual(msgs.count, 3)
        XCTAssertEqual(msgs[1]["role"] as? String, "assistant")
        XCTAssertEqual(msgs[2]["role"] as? String, "user")
    }

    func testNoNotesLeavesSystemAsBarePersona() {
        let msgs = replyMessages(persona: "PERSONA", store: MemoryStore(),
                                 imageBase64: "X", userText: "R")
        XCTAssertEqual(msgs.count, 2)                              // system + current user
        XCTAssertEqual(msgs[0]["content"] as? String, "PERSONA")  // unchanged
    }

    func testBodyRoundTrips() throws {
        let msgs = replyMessages(persona: "P", store: MemoryStore(), imageBase64: "X", userText: "R")
        let data = chatCompletionsBody(config: OracleConfig(apiKey: "k"), messages: msgs)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["stream"] as? Bool, true)
        XCTAssertEqual(obj?["model"] as? String, Persona.replyModel)
        XCTAssertNotNil(obj?["messages"])
    }
}
