import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class InteractiveDismissTests: XCTestCase {
    func testDisabledGesturesNeitherBeginNorDeliverDismissal() throws {
        let gesture = GestureDriver()
        let installed = (gesture.controller.view.gestureRecognizers ?? []).filter { $0.delegate === gesture.coordinator }
        let pan = try XCTUnwrap(installed.first { $0 is UIPanGestureRecognizer && !($0 is UIScreenEdgePanGestureRecognizer) })
        let edge = try XCTUnwrap(installed.first { $0 is UIScreenEdgePanGestureRecognizer })
        let recognizers = [pan, edge]
        for recognizer in recognizers {
            XCTAssertTrue(gesture.coordinator.gestureRecognizerShouldBegin(recognizer))
        }

        gesture.coordinator.isEnabled = false
        for recognizer in recognizers {
            XCTAssertFalse(gesture.coordinator.gestureRecognizerShouldBegin(recognizer))
        }
        // Also guard an already queued delivery, not just the should-begin decision.
        try gesture.send(.ended, offset: CGPoint(x: 0, y: 100))
        try gesture.send(.ended, offset: CGPoint(x: 100, y: 0), edge: true)
        XCTAssertEqual(gesture.events.dismissals, 0)
        XCTAssertTrue(gesture.events.pans.isEmpty)
        XCTAssertTrue(gesture.events.endings.isEmpty)
        XCTAssertTrue(gesture.controller.view.isUserInteractionEnabled)
    }

    func testDisablingDuringAPullCancelsItAndAllowsALaterPull() throws {
        let gesture = GestureDriver()
        try gesture.send(.began, offset: CGPoint(x: 0, y: 20))
        XCTAssertEqual(gesture.events.pans, [CGPoint(x: 0, y: 20)])

        gesture.coordinator.isEnabled = false
        XCTAssertEqual(gesture.events.endings, [false], "The destination must return to rest as soon as dismissal is disabled")
        try gesture.send(.ended, offset: CGPoint(x: 0, y: 100))
        XCTAssertEqual(gesture.events.dismissals, 0)
        XCTAssertEqual(gesture.events.endings, [false], "A queued release must not finish the cancelled pull again")

        gesture.coordinator.isEnabled = true
        try gesture.send(.began, offset: CGPoint(x: 0, y: 20))
        try gesture.send(.ended, offset: CGPoint(x: 0, y: 100))
        XCTAssertEqual(gesture.events.dismissals, 1)
        XCTAssertEqual(gesture.events.endings, [false, true])
    }

    func testSystemCancellationPastThresholdDoesNotDismissAndNextPullWorks() throws {
        for terminalState in [UIGestureRecognizer.State.cancelled, .failed] {
            let gesture = GestureDriver()
            try gesture.send(.began, offset: .zero)
            try gesture.send(.changed, offset: CGPoint(x: 0, y: 100))
            try gesture.send(terminalState, offset: CGPoint(x: 0, y: 100))
            XCTAssertEqual(gesture.events.dismissals, 0, "\(terminalState)")
            XCTAssertEqual(gesture.events.endings, [false], "\(terminalState)")

            try gesture.send(.began, offset: .zero)
            try gesture.send(.ended, offset: CGPoint(x: 0, y: 100))
            XCTAssertEqual(gesture.events.dismissals, 1)
            XCTAssertEqual(gesture.events.endings, [false, true])
        }
    }

    func testDismissalDirectionsAndShortPulls() throws {
        let cases: [(offset: CGPoint, edge: Bool, swipeUp: Bool, dismisses: Bool)] = [
            (CGPoint(x: 0, y: 20), false, false, false),
            (CGPoint(x: 0, y: 100), false, false, true),
            (CGPoint(x: 100, y: 0), false, false, false),
            (CGPoint(x: 100, y: 0), true, false, true),
            (CGPoint(x: 0, y: -200), false, false, false),
            (CGPoint(x: 0, y: -200), false, true, true)
        ]
        for item in cases {
            let gesture = GestureDriver()
            gesture.coordinator.swipeUpToDismiss = item.swipeUp
            try gesture.send(.began, offset: .zero, edge: item.edge)
            try gesture.send(.ended, offset: item.offset, edge: item.edge)
            XCTAssertEqual(gesture.events.dismissals, item.dismisses ? 1 : 0, "\(item)")
            XCTAssertEqual(gesture.events.endings, [item.dismisses], "\(item)")
        }
    }
}

/// Supplies finger input to the coordinator's existing UIKit target-action entry
/// points. Only recognizer state/translation are simulated; dismissal decisions,
/// cancellation, callbacks and installed recognizer delegates are production code.
@MainActor
private final class GestureDriver {
    final class Events {
        var pans: [CGPoint] = []
        var endings: [Bool] = []
        var dismissals = 0
    }

    let events: Events
    let coordinator: InteractiveDismissCoordinator
    let controller: InteractiveDismissViewController<Color>
    private let input = DismissGestureInput()
    private let inputView = UIView()

    init() {
        let events = Events()
        self.events = events
        coordinator = InteractiveDismissCoordinator(threshold: 80, isEnabled: true, onPan: { events.pans.append($0) }, isDismissing: false, swipeUpToDismiss: false, onDismiss: { events.dismissals += 1 }, onEnded: { events.endings.append($0) })
        controller = InteractiveDismissViewController(rootView: Color.clear, coordinator: coordinator)
        controller.loadViewIfNeeded()
        controller.findScrollViews()
        // The action uses the recognizer's view as its translation coordinate space.
        inputView.addGestureRecognizer(input)
    }

    func send(_ state: UIGestureRecognizer.State, offset: CGPoint, edge: Bool = false) throws {
        try input.send(state, offset: offset, edge: edge, to: coordinator)
    }
}

/// Test input at the UIKit action boundary, shared with the hosted FlowStack test.
final class DismissGestureInput: UIScreenEdgePanGestureRecognizer {
    private var deliveredState: UIGestureRecognizer.State = .possible
    private var offset: CGPoint = .zero

    func send(_ state: UIGestureRecognizer.State, offset: CGPoint, edge: Bool = false, to coordinator: InteractiveDismissCoordinator) throws {
        deliveredState = state
        self.offset = offset
        let selector = NSSelectorFromString(edge ? "edgeGestureUpdatedWithRecognizer:" : "panGestureUpdatedWithRecognizer:")
        // A renamed entry point must fail explicitly, not make negative tests pass.
        guard coordinator.responds(to: selector) else {
            throw NSError(domain: "Missing gesture action \(selector)", code: 1)
        }
        coordinator.perform(selector, with: self)
    }
    override var state: UIGestureRecognizer.State {
        get { deliveredState }
        set { }
    }
    override func translation(in view: UIView?) -> CGPoint { offset }
}
