import XCTest
@testable import RiddleKit

final class RequestBodyTests: XCTestCase {
    func testBodyShape() throws {
        let cfg = OracleConfig(baseURL: "https://openrouter.ai/api/v1",
                               apiKey: "k", model: "google/gemini-3.1-flash-lite", maxTokens: 2000)
        let data = chatCompletionsBody(config: cfg, systemPrompt: "SYS",
                                       userText: "Reply to what is written in the diary.",
                                       imageBase64: "QUJD")
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "google/gemini-3.1-flash-lite")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["max_tokens"] as? Int, 2000)
        let msgs = json["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0]["role"] as? String, "system")
        XCTAssertEqual(msgs[0]["content"] as? String, "SYS")
        let parts = msgs[1]["content"] as! [[String: Any]]
        let imgPart = parts.first { $0["type"] as? String == "image_url" }!
        let url = (imgPart["image_url"] as! [String: Any])["url"] as! String
        XCTAssertEqual(url, "data:image/png;base64,QUJD")
    }
    func testBaseURLTrailingSlashTrimmed() {
        let cfg = OracleConfig(baseURL: "https://x.example/v1/", apiKey: "k")
        XCTAssertEqual(cfg.baseURL, "https://x.example/v1")
    }
}
