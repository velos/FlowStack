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
