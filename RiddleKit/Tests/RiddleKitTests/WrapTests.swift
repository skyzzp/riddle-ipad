import XCTest
import CoreText
@testable import RiddleKit

final class WrapTests: XCTestCase {
    func testMeasureGrows() {
        let font = QuillFont.tomHand(px: 96)
        XCTAssertLessThan(RiddleKit.measure(font, "Hi"), RiddleKit.measure(font, "Hi there friend"))
    }
    func testWrapSplits() {
        let font = QuillFont.tomHand(px: 96)
        let lines = wrap(font, "Do you know anything about the Chamber of Secrets?", px: 96, maxPx: 700)
        XCTAssertGreaterThanOrEqual(lines.count, 2)
        XCTAssertFalse(lines.contains { $0.isEmpty })
    }
    func testRasterizeNonEmpty() {
        let font = QuillFont.tomHand(px: 96)
        let line = rasterizeLine(font, "Yes, Harry?", 96)
        XCTAssertGreaterThan(line.width, 100)
        XCTAssertGreaterThan(line.height, 50)
        XCTAssertTrue(line.mask.contains(true))
    }
}
