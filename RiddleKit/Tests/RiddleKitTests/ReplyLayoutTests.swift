import XCTest
import CoreGraphics
@testable import RiddleKit

final class ReplyLayoutTests: XCTestCase {
    func testPlanCentersAndAdvances() {
        let font = QuillFont.tomHand(px: 96)
        let plan = planReply(font: font, text: "Yes, Harry? I remember you.",
                             px: 96, pageWidth: 1000, pageHeight: 1400, yStart: nil)
        XCTAssertFalse(plan.strokes.isEmpty)
        XCTAssertGreaterThan(plan.nextY, 0)
        for stroke in plan.strokes { for pt in stroke {
            XCTAssertGreaterThanOrEqual(pt.x, 0); XCTAssertLessThanOrEqual(pt.x, 1000)
        } }
    }
    func testAppendContinuesBelow() {
        let font = QuillFont.tomHand(px: 96)
        let first = planReply(font: font, text: "Hello.", px: 96, pageWidth: 1000, pageHeight: 1400, yStart: nil)
        let cont = planReply(font: font, text: "Again.", px: 96, pageWidth: 1000, pageHeight: 1400, yStart: first.nextY)
        let firstMaxY = first.strokes.flatMap { $0 }.map { $0.y }.max() ?? 0
        let contMinY = cont.strokes.flatMap { $0 }.map { $0.y }.min() ?? 0
        XCTAssertGreaterThanOrEqual(contMinY, firstMaxY - 96)
    }
}
