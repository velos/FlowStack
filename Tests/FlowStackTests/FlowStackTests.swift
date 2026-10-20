import SwiftUI
import XCTest
@testable import FlowStack

/// Stands in for the object whose identity a flow link registers under.
private final class OwnerToken {}
private var ownerTokens: [OwnerToken] = []

/// A distinct owner, kept alive so that its identity isn't reused.
private func owner() -> ObjectIdentifier {
    let token = OwnerToken()
    ownerTokens.append(token)
    return ObjectIdentifier(token)
}

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

final class FlowPresentationStyleTests: XCTestCase {

    func testFullScreenAlwaysFills() {
        for idiom in [UIUserInterfaceIdiom.phone, .pad] {
            XCTAssertTrue(FlowPresentationStyle.fullScreen.isFullScreen(cardFits: true, idiom: idiom))
            XCTAssertTrue(FlowPresentationStyle.fullScreen.isFullScreen(cardFits: false, idiom: idiom))
        }
    }

    func testCardPresentsCardWheneverOneFits() {
        for idiom in [UIUserInterfaceIdiom.phone, .pad] {
            XCTAssertFalse(FlowPresentationStyle.card.isFullScreen(cardFits: true, idiom: idiom))
            XCTAssertTrue(FlowPresentationStyle.card.isFullScreen(cardFits: false, idiom: idiom))
        }
    }

    func testAutomaticFillsOnPhoneEvenWhenCardFits() {
        // e.g. an unfolded iPhone Duo or a landscape iPhone Pro Max.
        XCTAssertTrue(FlowPresentationStyle.automatic.isFullScreen(cardFits: true, idiom: .phone))
        XCTAssertTrue(FlowPresentationStyle.automatic.isFullScreen(cardFits: false, idiom: .phone))
    }

    func testAutomaticPresentsCardOnPadWhenOneFits() {
        XCTAssertFalse(FlowPresentationStyle.automatic.isFullScreen(cardFits: true, idiom: .pad))
        // e.g. iPad Split View or Slide Over at compact width.
        XCTAssertTrue(FlowPresentationStyle.automatic.isFullScreen(cardFits: false, idiom: .pad))
    }

    func testConfigurationDefaultsToAutomatic() {
        XCTAssertEqual(FlowLink<EmptyView>.Configuration().presentationStyle, .automatic)
        XCTAssertEqual(PathContext().presentationStyle, .automatic)
    }
}

final class ScrollRevealTests: XCTestCase {

    private let margin = ScrollRevealController.margin

    /// A 400x800 scroll view under a 100pt navigation bar, showing 3000pt of content.
    private func offset(revealing frame: CGRect, scrolledTo y: CGFloat, contentHeight: CGFloat = 3000) -> CGPoint {
        ScrollRevealController.contentOffset(
            revealing: frame,
            in: CGRect(x: 0, y: y, width: 400, height: 800),
            insets: UIEdgeInsets(top: 100, left: 0, bottom: 34, right: 0),
            contentSize: CGSize(width: 400, height: contentHeight)
        )
    }

    func testFullyVisibleFrameLeavesOffsetUnchanged() {
        let frame = CGRect(x: 16, y: 1300, width: 368, height: 300)
        XCTAssertEqual(offset(revealing: frame, scrolledTo: 1000), CGPoint(x: 0, y: 1000))
    }

    func testFrameUnderTheNavigationBarIsBroughtOutFromUnderIt() {
        // Visible content starts at 1000 + 100; this frame starts above that.
        let frame = CGRect(x: 16, y: 1050, width: 368, height: 300)
        let result = offset(revealing: frame, scrolledTo: 1000)
        XCTAssertEqual(result.y, 1050 - 100 - margin)
    }

    func testFrameBelowTheVisibleAreaIsAlignedToItsBottom() {
        let frame = CGRect(x: 16, y: 1700, width: 368, height: 300)
        let result = offset(revealing: frame, scrolledTo: 1000)
        // Visible content ends at offset + 800 - 34 - margin.
        XCTAssertEqual(result.y + 800 - 34 - margin, frame.maxY)
    }

    func testFrameTallerThanTheVisibleAreaIsAlignedToItsTop() {
        let frame = CGRect(x: 16, y: 1200, width: 368, height: 900)
        let result = offset(revealing: frame, scrolledTo: 1000)
        XCTAssertEqual(result.y, 1200 - 100 - margin)
    }

    func testOffsetIsClampedToTheStartOfTheContent() {
        // The first item can't be given a margin without scrolling past the top.
        let frame = CGRect(x: 16, y: 0, width: 368, height: 300)
        let result = offset(revealing: frame, scrolledTo: 40)
        XCTAssertEqual(result.y, -100)
    }

    func testOffsetIsClampedToTheEndOfTheContent() {
        let frame = CGRect(x: 16, y: 2700, width: 368, height: 300)
        let result = offset(revealing: frame, scrolledTo: 2000)
        XCTAssertEqual(result.y, 3000 - 800 + 34)
    }

    func testContentThatDoesNotScrollIsLeftAlone() {
        let frame = CGRect(x: 16, y: -50, width: 368, height: 300)
        let result = offset(revealing: frame, scrolledTo: -100, contentHeight: 400)
        XCTAssertEqual(result, CGPoint(x: 0, y: -100))
    }
}

final class FlowLinkContextStoreTests: XCTestCase {

    private func key(_ value: String, level: Int? = 0) -> FlowLinkContextStore.Key {
        .init(value: AnyHashable(value), level: level)
    }

    func testContextIsResolvedByValueAndLevel() {
        let store = FlowLinkContextStore()
        store.update(PathContext(cornerRadius: 7), for: key("a"), owner: owner(), reveal: {})

        XCTAssertEqual(store.context(for: AnyHashable("a"), atLevel: 0)?.cornerRadius, 7)
        XCTAssertNil(store.context(for: AnyHashable("a"), atLevel: 1))
        XCTAssertNil(store.context(for: AnyHashable("b"), atLevel: 0))
    }

    func testLinkWithoutALevelMatchesAnyLevel() {
        let store = FlowLinkContextStore()
        store.update(PathContext(cornerRadius: 7), for: key("a", level: nil), owner: owner(), reveal: {})

        XCTAssertEqual(store.context(for: AnyHashable("a"), atLevel: 3)?.cornerRadius, 7)
    }

    func testRemovingIsIgnoredOnceAnotherLinkHasTakenOver() {
        // When a layout swaps containers, the replacement link registers before
        // the link it replaces disappears.
        let store = FlowLinkContextStore()
        let old = owner(), replacement = owner()
        store.update(PathContext(cornerRadius: 1), for: key("a"), owner: old, reveal: {})
        store.update(PathContext(cornerRadius: 2), for: key("a"), owner: replacement, reveal: {})

        store.remove(key("a"), owner: old)
        XCTAssertEqual(store.context(for: AnyHashable("a"), atLevel: 0)?.cornerRadius, 2)

        store.remove(key("a"), owner: replacement)
        XCTAssertNil(store.context(for: AnyHashable("a"), atLevel: 0))
    }

    func testDismissingAnElementRevealsItsLink() {
        let store = FlowLinkContextStore()
        var revealed: [String] = []
        store.update(PathContext(), for: key("a"), owner: owner(), reveal: { revealed.append("a") })
        store.update(PathContext(), for: key("b", level: 1), owner: owner(), reveal: { revealed.append("b") })

        var path = FlowPath()
        path.append("a")
        path.append("b")
        store.pathDidChange(to: path.elements)
        waitForNextRunLoopPass()
        XCTAssertEqual(revealed, [], "Presenting must never move a link")

        path.removeLast()
        store.pathDidChange(to: path.elements)
        waitForNextRunLoopPass()
        XCTAssertEqual(revealed, ["b"])

        path.removeAll()
        store.pathDidChange(to: path.elements)
        waitForNextRunLoopPass()
        XCTAssertEqual(revealed, ["b", "a"])
    }

    func testDismissalSeenInThePathIsHandledAfterTheViewUpdate() {
        // The path changes during a view update, where a snapshot can't be taken.
        let store = FlowLinkContextStore()
        var events: [String] = []
        store.update(PathContext(), for: key("a"), owner: owner(), reveal: { events.append("reveal") }, prepareSnapshot: { events.append("snapshot") })

        var path = FlowPath()
        path.append("a")
        store.pathDidChange(to: path.elements)
        path.removeLast()
        store.pathDidChange(to: path.elements)
        XCTAssertEqual(events, [], "Nothing may happen until the view update is over")

        waitForNextRunLoopPass()
        XCTAssertEqual(events, ["reveal", "snapshot"])
    }

    func testDismissalThatRevealedItsLinkDoesNotRevealItAgain() {
        // FlowDismissAction reveals the link before it removes the element, so the path
        // change that follows has nothing left to do.
        let store = FlowLinkContextStore()
        var reveals = 0
        store.update(PathContext(), for: key("a"), owner: owner(), reveal: { reveals += 1 })

        var path = FlowPath()
        path.append("a")
        store.pathDidChange(to: path.elements)

        store.revealLink(for: AnyHashable("a"), atLevel: 0) { path.removeLast() }
        store.pathDidChange(to: path.elements)
        waitForNextRunLoopPass()
        XCTAssertEqual(reveals, 1)

        // Presented and dismissed again, this time by removing it from the path directly.
        path.append("a")
        store.pathDidChange(to: path.elements)
        path.removeLast()
        store.pathDidChange(to: path.elements)
        waitForNextRunLoopPass()
        XCTAssertEqual(reveals, 2)
    }

    private func waitForNextRunLoopPass() {
        let passed = expectation(description: "next run loop pass")
        DispatchQueue.main.async { passed.fulfill() }
        wait(for: [passed], timeout: 1)
    }
}

final class FlowLinkRevealTests: XCTestCase {

    func testRevealingAnExistingLinkCompletesImmediately() {
        let store = FlowLinkContextStore()
        var events: [String] = []
        store.update(
            PathContext(),
            for: .init(value: AnyHashable("a"), level: 0),
            owner: owner(),
            reveal: { events.append("reveal") },
            prepareSnapshot: { events.append("snapshot") }
        )

        store.revealLink(for: AnyHashable("a"), atLevel: 0) { events.append("completion") }

        // The snapshot is ready before the dismissal is allowed to begin.
        XCTAssertEqual(events, ["reveal", "snapshot", "completion"])
    }

    func testRevealingWithNothingToScrollCompletesImmediately() {
        // No link and no scroll view to find one in: the dismissal must not be held up.
        let store = FlowLinkContextStore()
        var completed = false

        store.revealLink(for: AnyHashable("a"), atLevel: 0) { completed = true }

        XCTAssertTrue(completed)
    }
}

final class SnapshotInputsTests: XCTestCase {

    private func inputs(size: CGSize? = CGSize(width: 300, height: 200), dynamicTypeSize: DynamicTypeSize = .large, value: AnyHashable? = AnyHashable("a")) -> SnapshotInputs {
        SnapshotInputs(
            value: value,
            size: size,
            dynamicTypeSize: dynamicTypeSize,
            legibilityWeight: .regular,
            colorSchemeContrast: .standard,
            layoutDirection: .leftToRight,
            locale: Locale(identifier: "en_US"),
            displayScale: 3
        )
    }

    func testUnchangedInputsKeepASnapshotCurrent() {
        XCTAssertEqual(inputs(), inputs())
    }

    func testResizingMakesASnapshotStale() {
        XCTAssertNotEqual(inputs(), inputs(size: CGSize(width: 150, height: 100)))
    }

    func testRestylingWithoutResizingMakesASnapshotStale() {
        // Larger text can reflow inside a frame that doesn't change.
        XCTAssertNotEqual(inputs(), inputs(dynamicTypeSize: .accessibility2))
    }

    func testPresentingAnotherValueMakesASnapshotStale() {
        XCTAssertNotEqual(inputs(), inputs(value: AnyHashable("b")))
    }
}

final class SafeAreaCompensationTests: XCTestCase {

    private typealias Controller = InteractiveDismissViewController<EmptyView>

    private let portrait = CGRect(x: 0, y: 0, width: 393, height: 852)
    private let portraitInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

    private let landscape = CGRect(x: 0, y: 0, width: 852, height: 393)
    private let landscapeInsets = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)

    private func compensation(_ frame: CGRect, restingAt resting: CGRect? = nil, in window: CGRect, insets: UIEdgeInsets) -> UIEdgeInsets {
        Controller.safeAreaCompensation(frame: frame, restingFrame: resting ?? window, windowBounds: window, windowInsets: insets)
    }

    func testViewAtRestNeedsNoCompensation() {
        XCTAssertEqual(compensation(portrait, in: portrait, insets: portraitInsets), .zero)
    }

    func testPullingDownMakesUpTheTopInsetItLoses() {
        let pulled = portrait.offsetBy(dx: 0, dy: 40)
        XCTAssertEqual(compensation(pulled, in: portrait, insets: portraitInsets).top, 40)
    }

    func testNoMoreIsMadeUpThanTheInsetThereWas() {
        let pulled = portrait.offsetBy(dx: 0, dy: 200)
        XCTAssertEqual(compensation(pulled, in: portrait, insets: portraitInsets).top, 59)
    }

    func testOverhangingAnEdgeGainsNothing() {
        // Pulled down, the view hangs off the bottom of the screen.
        let pulled = portrait.offsetBy(dx: 0, dy: 40)
        XCTAssertEqual(compensation(pulled, in: portrait, insets: portraitInsets).bottom, 0)
    }

    func testEdgeSwipeInLandscapeMakesUpTheLeadingInset() {
        // The island can be on either side; an edge swipe drags the view away from the left.
        let swiped = landscape.offsetBy(dx: 30, dy: 0)
        let result = compensation(swiped, in: landscape, insets: landscapeInsets)
        XCTAssertEqual(result.left, 30)
        XCTAssertEqual(result.right, 0)
    }

    func testEveryEdgeIsMadeUpForAViewThatShrinksInPlace() {
        let shrunk = landscape.insetBy(dx: 20, dy: 10)
        let result = compensation(shrunk, in: landscape, insets: landscapeInsets)
        XCTAssertEqual(result, UIEdgeInsets(top: 0, left: 20, bottom: 10, right: 20))
    }

    func testViewThatRestsAwayFromTheEdgesDoesNotJumpWhenAPullBegins() {
        // A card on iPad rests clear of every inset, so it has none to lose.
        let window = CGRect(x: 0, y: 0, width: 1024, height: 1366)
        let insets = UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)
        let card = window.insetBy(dx: 159, dy: 184)

        XCTAssertEqual(compensation(card, restingAt: card, in: window, insets: insets), .zero)
        XCTAssertEqual(compensation(card.offsetBy(dx: 0, dy: 50), restingAt: card, in: window, insets: insets), .zero)
    }

    func testViewCountsAsBackAtRestOnceItIsTooCloseToTell() {
        // A view that was let go springs back, and gets there by ever smaller amounts.
        XCTAssertTrue(portrait.offsetBy(dx: 0, dy: 0.05).isApproximatelyEqual(to: portrait))
        XCTAssertTrue(portrait.insetBy(dx: 0.02, dy: 0.02).isApproximatelyEqual(to: portrait))
        XCTAssertFalse(portrait.offsetBy(dx: 0, dy: 0.5).isApproximatelyEqual(to: portrait))
        XCTAssertFalse(portrait.insetBy(dx: 0, dy: 0.5).isApproximatelyEqual(to: portrait))
    }
}

final class FlowLinkIdentityTests: XCTestCase {

    private func key(_ value: String, level: Int? = 0) -> FlowLinkContextStore.Key {
        .init(value: AnyHashable(value), level: level)
    }

    private let a = AnyHashable("a")

    // MARK: Which link a destination came from

    func testDestinationComesFromTheLinkThatPresentedIt() {
        let tapped = FlowLinkIdentity.instance(owner()), twin = FlowLinkIdentity.instance(owner())
        let source = FlowLinkSource(link: tapped, passedOver: [twin])

        XCTAssertTrue(source.includes(tapped))
        XCTAssertFalse(source.includes(twin))
    }

    func testLinkCreatedSinceIsTakenForTheOneThatWasRecreated() {
        // A change of layout replaces the link that was activated with another instance.
        let source = FlowLinkSource(link: .instance(owner()), passedOver: [.instance(owner())])
        XCTAssertTrue(source.includes(.instance(owner())))
    }

    func testExplicitIdentitiesOnlyEverMatchThemselves() {
        let source = FlowLinkSource(link: .explicit("featured"))

        XCTAssertTrue(source.includes(.explicit("featured")))
        XCTAssertFalse(source.includes(.explicit("list")))
        XCTAssertFalse(source.includes(.instance(owner())))
        // Nor is a link with an identifier ever taken for a recreated link without one.
        XCTAssertFalse(FlowLinkSource(link: .instance(owner())).includes(.explicit("featured")))
    }

    func testAppendingWithALinkIDRecordsTheLink() {
        var path = FlowPath()
        path.append("a", linkID: "featured")
        path.append("b")

        XCTAssertEqual(path.elements[0].source, FlowLinkSource(link: .explicit("featured")))
        XCTAssertNil(path.elements[1].source)
    }

    // MARK: Links presenting the same value

    func testEachLinkPresentingAValueKeepsItsOwnContext() {
        let store = FlowLinkContextStore()
        let featured = owner(), listed = owner()
        store.update(PathContext(cornerRadius: 1), for: key("a"), owner: featured, reveal: {})
        store.update(PathContext(cornerRadius: 2), for: key("a"), owner: listed, reveal: {})

        let fromFeatured = FlowLinkSource(link: .instance(featured), passedOver: [.instance(listed)])
        let fromListed = FlowLinkSource(link: .instance(listed), passedOver: [.instance(featured)])
        XCTAssertEqual(store.context(for: a, atLevel: 0, source: fromFeatured)?.cornerRadius, 1)
        XCTAssertEqual(store.context(for: a, atLevel: 0, source: fromListed)?.cornerRadius, 2)

        // The link reporting again, as it does when it scrolls, changes nothing.
        store.update(PathContext(cornerRadius: 1), for: key("a"), owner: featured, reveal: {})
        XCTAssertEqual(store.context(for: a, atLevel: 0, source: fromListed)?.cornerRadius, 2)
    }

    func testLinkKnowsWhichOthersPresentItsValue() {
        let store = FlowLinkContextStore()
        let featured = owner(), listed = owner(), overlaid = owner(), deeper = owner(), unrelated = owner()
        store.update(PathContext(), for: key("a"), owner: featured, reveal: {})
        store.update(PathContext(), for: key("a"), owner: listed, reveal: {})
        store.update(PathContext(), for: key("a", level: nil), owner: overlaid, reveal: {})
        store.update(PathContext(), for: key("a", level: 1), owner: deeper, reveal: {})
        store.update(PathContext(), for: key("b"), owner: unrelated, reveal: {})

        let others = store.identities(presentingSameValueAs: key("a"), otherThan: .instance(featured))
        XCTAssertEqual(others, [.instance(listed), .instance(overlaid)])
    }

    func testDestinationReturnsToTheRecreatedLinkRatherThanTheOneItPassedOver() {
        let store = FlowLinkContextStore()
        let featured = owner(), listed = owner(), recreated = owner()
        store.update(PathContext(cornerRadius: 1), for: key("a"), owner: featured, reveal: {})
        store.update(PathContext(cornerRadius: 2), for: key("a"), owner: listed, reveal: {})
        let source = FlowLinkSource(link: .instance(featured), passedOver: [.instance(listed)])

        // The replacement registers before the link it replaces disappears, and the
        // destination stays with the link it came from for as long as that lasts.
        store.update(PathContext(cornerRadius: 3), for: key("a"), owner: recreated, reveal: {})
        XCTAssertEqual(store.context(for: a, atLevel: 0, source: source)?.cornerRadius, 1)

        store.remove(key("a"), owner: featured)
        XCTAssertEqual(store.context(for: a, atLevel: 0, source: source)?.cornerRadius, 3)

        // With only the link it passed over left, it has nowhere to return to.
        store.remove(key("a"), owner: recreated)
        XCTAssertNil(store.context(for: a, atLevel: 0, source: source))
    }

    func testLinkWithAnIdentifierIsFoundAgainHoweverItIsRecreated() {
        let store = FlowLinkContextStore()
        let featured = owner(), listed = owner()
        store.update(PathContext(cornerRadius: 1), for: key("a"), identity: .explicit("featured"), owner: featured, reveal: {})
        store.update(PathContext(cornerRadius: 2), for: key("a"), identity: .explicit("list"), owner: listed, reveal: {})
        let source = FlowLinkSource(link: .explicit("featured"))

        // Both links are recreated, the listed one last.
        let newFeatured = owner(), newListed = owner()
        store.update(PathContext(cornerRadius: 3), for: key("a"), identity: .explicit("featured"), owner: newFeatured, reveal: {})
        store.update(PathContext(cornerRadius: 4), for: key("a"), identity: .explicit("list"), owner: newListed, reveal: {})
        store.remove(key("a"), owner: featured)
        store.remove(key("a"), owner: listed)

        XCTAssertEqual(store.context(for: a, atLevel: 0, source: source)?.cornerRadius, 3)
    }

    func testValueAppendedDirectlyReturnsToTheLatestLinkPresentingIt() {
        let store = FlowLinkContextStore()
        store.update(PathContext(cornerRadius: 1), for: key("a"), owner: owner(), reveal: {})
        store.update(PathContext(cornerRadius: 2), for: key("a"), owner: owner(), reveal: {})

        XCTAssertEqual(store.context(for: a, atLevel: 0)?.cornerRadius, 2)
    }

    func testRevealScrollsTheLinkTheDestinationCameFrom() {
        let store = FlowLinkContextStore()
        let featured = owner(), listed = owner()
        var revealed: [String] = []
        store.update(PathContext(), for: key("a"), owner: featured, reveal: { revealed.append("featured") })
        store.update(PathContext(), for: key("a"), owner: listed, reveal: { revealed.append("listed") })

        store.revealLink(for: a, atLevel: 0, source: FlowLinkSource(link: .instance(featured), passedOver: [.instance(listed)]))
        XCTAssertEqual(revealed, ["featured"])
    }
}
