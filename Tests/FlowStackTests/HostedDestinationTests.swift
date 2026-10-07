import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class HostedDestinationTests: XCTestCase {
    func testDisabledDismissalKeepsTheDestinationInteractiveThenCanBeEnabled() async throws {
        let model = StackInputs()
        let host = HostedView(StackFixture(model: model))
        defer { host.close() }
        try await waitFor("presented destination") { self.button(in: host.controller.view)?.title(for: .normal) == "live:0" }
        let (dismissView, coordinator) = try XCTUnwrap(dismissalHost(in: host.controller.view))
        try await waitFor("disabled preference to reach the recognizer") { !coordinator.isEnabled }

        let input = DismissGestureInput()
        let inputView = UIView()
        inputView.addGestureRecognizer(input)
        try input.send(.ended, offset: CGPoint(x: 0, y: 100), to: coordinator)
        let button = try XCTUnwrap(button(in: host.controller.view))
        button.sendActions(for: .touchUpInside)
        try await waitFor("content update after the rejected gesture") { button.title(for: .normal) == "live:1" }
        XCTAssertEqual(model.path.count, 1)
        var ancestor: UIView? = button
        while let view = ancestor {
            XCTAssertTrue(view.isUserInteractionEnabled, "A rejected dismissal must not disable the destination's view hierarchy")
            ancestor = view.superview
        }

        model.disabled = false
        try await waitFor("dismissal to be enabled") { coordinator.isEnabled }

        // Disabling while the finger is down reaches the coordinator through a
        // representable update, unlike the direct coordinator cancellation test.
        let restingFrame = dismissView.convert(dismissView.bounds, to: host.controller.view)
        try input.send(.began, offset: CGPoint(x: 0, y: 40), to: coordinator)
        try await waitFor("destination to move with the pull") {
            abs(dismissView.convert(dismissView.bounds, to: host.controller.view).minY - restingFrame.minY) > 1
        }
        model.disabled = true
        try await waitFor("cancelled destination to return to rest") {
            !coordinator.isEnabled && abs(dismissView.convert(dismissView.bounds, to: host.controller.view).minY - restingFrame.minY) < 1
        }
        XCTAssertEqual(model.path.count, 1)
        model.disabled = false
        try await waitFor("dismissal to be enabled again") { coordinator.isEnabled }
        try input.send(.ended, offset: CGPoint(x: 0, y: 100), to: coordinator)
        try await waitFor("accepted dismissal to remove the destination") { model.path.isEmpty }
    }

    func testNewInputsReachContentWithoutResettingItsState() async throws {
        let model = DestinationInputs()
        let host = HostedView(DestinationFixture(model: model))
        defer { host.close() }

        try await waitFor("initial destination") { self.button(in: host.controller.view)?.title(for: .normal) == "before:0" }
        let button = try XCTUnwrap(button(in: host.controller.view))
        button.sendActions(for: .touchUpInside)
        try await waitFor("local state change") { button.title(for: .normal) == "before:1" }

        model.value = "after"
        try await waitFor("updated content with preserved state") { self.button(in: host.controller.view)?.title(for: .normal) == "after:1" }
        let updatedButton = try XCTUnwrap(self.button(in: host.controller.view))
        updatedButton.sendActions(for: .touchUpInside)
        try await waitFor("content still accepting input") { updatedButton.title(for: .normal) == "after:2" }
    }

    func testContentUpdatePreservesFocusedTextEntry() async throws {
        let model = DestinationInputs()
        let host = HostedView(DestinationFixture(model: model))
        defer { host.close() }
        try await waitFor("text field") { self.textField(in: host.controller.view) != nil }
        let field = try XCTUnwrap(textField(in: host.controller.view))
        XCTAssertTrue(field.becomeFirstResponder())
        field.text = "unsaved note"
        field.sendActions(for: .editingChanged)
        try await waitFor("text entry to reach SwiftUI state") { self.button(in: host.controller.view)?.accessibilityValue == "unsaved note" }

        model.value = "after"
        try await waitFor("content update while editing") { self.button(in: host.controller.view)?.title(for: .normal) == "after:0" }
        let updatedField = try XCTUnwrap(textField(in: host.controller.view))
        XCTAssertEqual(updatedField.text, "unsaved note")
        XCTAssertTrue(updatedField.isFirstResponder, "Refreshing destination inputs must not dismiss its keyboard")
    }

    private func button(in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == "destination-counter" { return button }
        return view.subviews.compactMap { button(in: $0) }.first
    }

    private func dismissalHost(in view: UIView) -> (UIView, InteractiveDismissCoordinator)? {
        if let coordinator = view.gestureRecognizers?.compactMap({ $0.delegate as? InteractiveDismissCoordinator }).first { return (view, coordinator) }
        return view.subviews.compactMap { dismissalHost(in: $0) }.first
    }

    private func textField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }
        return view.subviews.compactMap { textField(in: $0) }.first
    }
}

private final class StackInputs: ObservableObject {
    @Published var path: FlowPath = {
        var path = FlowPath()
        path.append("destination")
        return path
    }()
    @Published var disabled = true
}

private struct StackFixture: View {
    @ObservedObject var model: StackInputs

    var body: some View {
        FlowStack(path: $model.path) {
            Color.clear.flowDestination(for: String.self) { _ in
                DismissibleDestination(model: model)
            }
        }
    }
}

private struct DismissibleDestination: View {
    @ObservedObject var model: StackInputs

    var body: some View {
        StatefulDestination(value: "live")
            .flowInteractiveDismissDisabled(model.disabled)
    }
}

private final class DestinationInputs: ObservableObject {
    @Published var value = "before"
}

private struct DestinationFixture: View {
    @ObservedObject var model: DestinationInputs

    var body: some View {
        InteractiveDismissContainer(threshold: 80, onPan: { _ in }, isEnabled: true, isDismissing: false, swipeUpToDismiss: false, onDismiss: {}, onEnded: { _ in }, content: StatefulDestination(value: model.value))
    }
}

private struct StatefulDestination: View {
    let value: String
    @State private var count = 0
    @State private var note = ""

    var body: some View {
        VStack {
            CounterButton(title: "\(value):\(count)", note: note) { count += 1 }
            NoteField(text: $note)
        }
    }
}

/// Gives the test a public UIKit control to read and activate inside real SwiftUI
/// content. SwiftUI owns the counter and all of its update/lifetime behavior.
private struct CounterButton: UIViewRepresentable {
    let title: String
    let note: String
    let action: () -> Void
    private static var actionID: UIAction.Identifier { UIAction.Identifier("increment") }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "destination-counter"
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.setTitle(title, for: .normal)
        button.accessibilityValue = note
        button.removeAction(identifiedBy: Self.actionID, for: .touchUpInside)
        button.addAction(UIAction(identifier: Self.actionID) { _ in action() }, for: .touchUpInside)
    }
}

/// Uses public UIControl events to enter text deterministically. The behavior under
/// test is hosting updates preserving SwiftUI state and UIKit first-responder status,
/// not SwiftUI TextField's private keyboard event plumbing.
private struct NoteField: UIViewRepresentable {
    @Binding var text: String
    private static var actionID: UIAction.Identifier { UIAction.Identifier("edit-note") }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "Note"
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text { field.text = text }
        field.removeAction(identifiedBy: Self.actionID, for: .editingChanged)
        field.addAction(UIAction(identifier: Self.actionID) { [weak field] _ in
            text = field?.text ?? ""
        }, for: .editingChanged)
    }
}
