import XCTest
@testable import RiddleKit

final class DissolveTests: XCTestCase {
    func testHashDeterministic() {
        XCTAssertEqual(pxHash(10, 20), pxHash(10, 20))
        XCTAssertNotEqual(pxHash(10, 20), pxHash(20, 10))
    }
    func testStagesCoverEverythingByLast() {
        let stages: UInt32 = 14
        for x in 0..<40 { for y in 0..<40 {
            XCTAssertTrue(dissolves(x: x, y: y, stage: stages - 1, stages: stages))
        } }
    }
    func testMonotone() {
        let stages: UInt32 = 14
        for x in 0..<20 { for y in 0..<20 {
            var seen = false
            for s in 0..<stages {
                let d = dissolves(x: x, y: y, stage: s, stages: stages)
                if seen { XCTAssertTrue(d) }
                if d { seen = true }
            }
        } }
    }
}
