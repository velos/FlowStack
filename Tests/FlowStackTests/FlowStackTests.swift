import XCTest
@testable import FlowStack

final class FlowPathTests: XCTestCase {

    func testAppendUpdatesCountAndIsEmpty() {
        var path = FlowPath()
        XCTAssertTrue(path.isEmpty)
        XCTAssertEqual(path.count, 0)

        path.append("first")
        path.append(2)

        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.count, 2)
    }

    func testAppendAssignsIncreasingIndices() {
        var path = FlowPath()
        path.append("a")
        path.append("b")
        path.append("c")

        XCTAssertEqual(path.elements.map(\.index), [0, 1, 2])
    }

    func testRemoveLast() {
        var path = FlowPath()
        path.append("a")
        path.append("b")

        path.removeLast()
        XCTAssertEqual(path.count, 1)

        path.removeLast()
        XCTAssertTrue(path.isEmpty)
    }

    func testRemoveLastOnEmptyPathDoesNothing() {
        var path = FlowPath()
        path.removeLast()
        XCTAssertTrue(path.isEmpty)
    }

    func testRemoveLastClampsCountToAvailableElements() {
        var path = FlowPath()
        path.append("a")
        path.append("b")

        path.removeLast(5)
        XCTAssertTrue(path.isEmpty)
    }

    func testRemoveLastIgnoresNegativeCount() {
        var path = FlowPath()
        path.append("a")

        path.removeLast(-1)
        XCTAssertEqual(path.count, 1)
    }

    func testRemoveAll() {
        var path = FlowPath()
        path.append("a")
        path.append("b")
        path.append("c")

        path.removeAll()
        XCTAssertTrue(path.isEmpty)
    }

    func testContainsAtAnyLevel() {
        var path = FlowPath()
        path.append("a")
        path.append("b")

        XCTAssertTrue(path.contains("a", atLevel: nil))
        XCTAssertTrue(path.contains("b", atLevel: nil))
        XCTAssertFalse(path.contains("c", atLevel: nil))
    }

    func testContainsAtSpecificLevel() {
        var path = FlowPath()
        path.append("a")
        path.append("b")

        XCTAssertTrue(path.contains("a", atLevel: 0))
        XCTAssertFalse(path.contains("a", atLevel: 1))
        XCTAssertTrue(path.contains("b", atLevel: 1))
    }

    func testEquality() {
        var first = FlowPath()
        first.append("a")

        var second = FlowPath()
        second.append("a")

        XCTAssertEqual(first, second)

        second.append("b")
        XCTAssertNotEqual(first, second)
    }
}

final class FlowElementTests: XCTestCase {

    /// A value with a deliberately constant hash, so that distinct values collide.
    private struct CollidingValue: Hashable {
        let id: Int

        func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
    }

    func testEqualValuesAtSameIndexAreEqual() {
        let lhs = FlowElement(value: "a", context: nil, index: 0)
        let rhs = FlowElement(value: "a", context: nil, index: 0)
        XCTAssertEqual(lhs, rhs)
    }

    func testDifferentIndicesAreNotEqual() {
        let lhs = FlowElement(value: "a", context: nil, index: 0)
        let rhs = FlowElement(value: "a", context: nil, index: 1)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testDifferentValuesOfSameTypeAreNotEqual() {
        let lhs = FlowElement(value: "a", context: nil, index: 0)
        let rhs = FlowElement(value: "b", context: nil, index: 0)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testDifferentValueTypesAreNotEqual() {
        let lhs = FlowElement(value: "a", context: nil, index: 0)
        let rhs = FlowElement(value: 1, context: nil, index: 0)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testHashCollidingValuesAreNotEqual() {
        // Distinct values whose hashes collide must still compare as different
        // elements; equality is based on value equality, not hash equality.
        let lhs = FlowElement(value: CollidingValue(id: 1), context: nil, index: 0)
        let rhs = FlowElement(value: CollidingValue(id: 2), context: nil, index: 0)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testHashIncorporatesValue() {
        let lhs = FlowElement(value: "a", context: nil, index: 0)
        let rhs = FlowElement(value: "b", context: nil, index: 0)
        XCTAssertNotEqual(lhs.hashValue, rhs.hashValue)
    }
}

final class CornerRadiiTests: XCTestCase {

    private let duo = CornerRadii(topLeft: 8, topRight: 59, bottomLeft: 8, bottomRight: 59)

    func testUniformInitializer() {
        let radii = CornerRadii(uniform: 12)
        XCTAssertTrue(radii.isUniform)
        XCTAssertEqual(radii.maximum, 12)
    }

    func testIsUniformDetectsDifferingCorners() {
        XCTAssertFalse(duo.isUniform)
        XCTAssertEqual(duo.maximum, 59)
    }

    func testInterpolationStartsAtSharedRadius() {
        XCTAssertEqual(duo.interpolated(from: 20, percent: 0), CornerRadii(uniform: 20))
    }

    func testInterpolationEndsAtEachCornersRadius() {
        XCTAssertEqual(duo.interpolated(from: 20, percent: 1), duo)
    }

    func testInterpolationMovesEachCornerIndependently() {
        let halfway = duo.interpolated(from: 20, percent: 0.5)
        XCTAssertEqual(halfway.topLeft, 14)
        XCTAssertEqual(halfway.bottomLeft, 14)
        XCTAssertEqual(halfway.topRight, 39.5)
        XCTAssertEqual(halfway.bottomRight, 39.5)
    }

    func testInterpolationNeverProducesNegativeRadii() {
        // Bouncy animations overshoot percent past 1, which extrapolates a
        // corner that shrinks (20 -> 8) toward and beyond zero.
        let overshot = duo.interpolated(from: 20, percent: 3)
        XCTAssertEqual(overshot.topLeft, 0)
        XCTAssertEqual(overshot.bottomLeft, 0)
    }

    func testAnimatableDataRoundTrips() {
        var radii = CornerRadii.zero
        radii.animatableData = duo.animatableData
        XCTAssertEqual(radii, duo)
    }

    func testMapTransformsEveryCorner() {
        XCTAssertEqual(duo.map { $0 / 2 }, CornerRadii(topLeft: 4, topRight: 29.5, bottomLeft: 4, bottomRight: 29.5))
    }
}
