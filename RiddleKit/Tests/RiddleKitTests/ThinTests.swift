import XCTest
@testable import RiddleKit

final class ThinTests: XCTestCase {
    func testThinningSlims() {
        let font = QuillFont.tomHand(px: 96)
        var line = rasterizeLine(font, "Yes, Harry?", 96)
        let before = line.mask.filter { $0 }.count
        thin(&line)
        let after = line.mask.filter { $0 }.count
        XCTAssertLessThan(after * 3, before)
        XCTAssertGreaterThan(after, 0)
    }
}
