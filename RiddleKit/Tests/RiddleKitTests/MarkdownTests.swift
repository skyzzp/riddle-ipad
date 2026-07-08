import XCTest
@testable import RiddleKit

final class MarkdownTests: XCTestCase {
    func testStripsEmphasisAndCode() {
        XCTAssertEqual(stripMarkdown("**bold** and *italic* and `code`"), "bold and italic and code")
    }
    func testStripsLeadingBlockMarkers() {
        XCTAssertEqual(stripMarkdown("# Heading"), "Heading")
        XCTAssertEqual(stripMarkdown("> quote"), "quote")
        XCTAssertEqual(stripMarkdown("- item"), "item")
    }
    func testLeavesPlainProse() {
        XCTAssertEqual(stripMarkdown("As real as this ink, my dear."), "As real as this ink, my dear.")
    }
    func testTimeoutIsQuiet() {
        XCTAssertNil(inCharacterError(for: URLError(.timedOut)))
    }
    func testOtherErrorsBlur() {
        XCTAssertEqual(inCharacterError(for: OracleError.http(401)),
                       "the ink blurred and would not settle…")
        XCTAssertEqual(inCharacterError(for: nil), "the ink blurred and would not settle…")
    }
}
