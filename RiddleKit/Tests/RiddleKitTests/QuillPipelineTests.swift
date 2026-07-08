import XCTest
@testable import RiddleKit

final class QuillPipelineTests: XCTestCase {
    func testPipelineProducesStrokes() {
        let font = QuillFont.tomHand(px: 96)
        var line = rasterizeLine(font, "Yes, Harry?", 96)
        XCTAssertTrue(line.width > 100 && line.height > 50)
        let before = line.mask.filter { $0 }.count
        thin(&line)
        let after = line.mask.filter { $0 }.count
        XCTAssertLessThan(after * 3, before)
        let strokes = trace(line)
        XCTAssertFalse(strokes.isEmpty)
        let total = strokes.reduce(0) { $0 + $1.count }
        XCTAssertGreaterThan(total, 200)
        let minXs = strokes.map { $0.map { $0.0 }.min() ?? 0 }
        XCTAssertEqual(minXs, minXs.sorted())
    }
}
