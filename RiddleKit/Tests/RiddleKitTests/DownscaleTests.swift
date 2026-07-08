import XCTest
@testable import RiddleKit

final class DownscaleTests: XCTestCase {
    func testFactorAndDims() {
        let src = [UInt8](repeating: 100, count: 4096 * 10)
        let out = boxDownscaleGray(src, width: 4096, height: 10, targetLongEdge: 2048)
        XCTAssertEqual(out.width, 2048)
        XCTAssertEqual(out.height, 5)
        XCTAssertEqual(out.pixels.first, 100)
    }
    func testNoUpscaleWhenSmaller() {
        let src = [UInt8](repeating: 0, count: 100 * 100)
        let out = boxDownscaleGray(src, width: 100, height: 100, targetLongEdge: 2048)
        XCTAssertEqual(out.width, 100)
        XCTAssertEqual(out.height, 100)
    }
    func testBlockAverage() {
        let src: [UInt8] = [0, 200, 200, 0]
        let out = boxDownscaleGray(src, width: 2, height: 2, targetLongEdge: 1)
        XCTAssertEqual(out.width, 1); XCTAssertEqual(out.height, 1)
        XCTAssertEqual(out.pixels, [100])
    }
}
