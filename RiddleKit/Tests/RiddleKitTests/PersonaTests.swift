import XCTest
@testable import RiddleKit

final class PersonaTests: XCTestCase {
    func testSystemPromptIsVerbatim() {
        XCTAssertTrue(Persona.systemPrompt.hasPrefix("You are the memory of Tom Marvolo Riddle"))
        XCTAssertTrue(Persona.systemPrompt.contains("say the ink blurred"))
        XCTAssertEqual(Persona.systemPrompt.count, 586)
    }
    func testModelDefaults() {
        XCTAssertEqual(Persona.replyModel, "google/gemini-3.1-flash-lite")
        XCTAssertEqual(Persona.sideModel, "google/gemini-2.5-flash-lite")
        XCTAssertEqual(Persona.defaultBaseURL, "https://openrouter.ai/api/v1")
    }
}
