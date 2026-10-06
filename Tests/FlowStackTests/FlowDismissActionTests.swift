import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class FlowDismissActionTests: XCTestCase {
    func testDismissWaitsForActionBeforeRemovingDestination() async throws {
        let model = DismissInputs()
        let host = HostedView(DismissFixture(model: model, action: { await model.pauseAction() }))
        defer { host.close(); model.finishAction() }

        try await waitFor("dismiss environment") { model.dismiss != nil }
        model.dismiss?()
        try await waitFor("action to start") { model.continuation != nil }
        XCTAssertEqual(model.path.count, 1)

        model.finishAction()
        try await waitFor("dismissal after action") { model.path.isEmpty }
        XCTAssertEqual(model.actionCalls, 1)
    }

    func testActionChangingPathDoesNotDismissReplacement() async throws {
        let model = DismissInputs()
        let host = HostedView(DismissFixture(model: model, action: { await model.pauseAction() }))
        defer { host.close(); model.finishAction() }

        try await waitFor("dismiss environment") { model.dismiss != nil }
        model.dismiss?()
        try await waitFor("action to start") { model.continuation != nil }
        model.path.removeLast()
        model.path.append("replacement")
        model.finishAction()
        try await waitFor("action to finish") { model.actionFinished }
        // Allow the task that awaited the callback to resume as well.
        await Task.yield()
        XCTAssertTrue(model.path.contains("replacement", atLevel: 0))
        XCTAssertEqual(model.path.count, 1)
    }

    func testDismissWithoutActionKeepsExistingBehavior() async throws {
        let model = DismissInputs()
        let host = HostedView(DismissFixture(model: model, action: nil))
        defer { host.close() }

        try await waitFor("dismiss environment") { model.dismiss != nil }
        model.dismiss?()
        try await waitFor("dismissal without an action") { model.path.isEmpty }
        XCTAssertEqual(model.actionCalls, 0)
    }
}

private final class DismissInputs: ObservableObject {
    @Published var path: FlowPath = {
        var path = FlowPath()
        path.append("initial")
        return path
    }()
    var dismiss: FlowDismissAction?
    var continuation: CheckedContinuation<Void, Never>?
    var actionCalls = 0
    var actionFinished = false

    @MainActor
    func pauseAction() async {
        actionCalls += 1
        await withCheckedContinuation { continuation = $0 }
        actionFinished = true
    }

    func finishAction() {
        continuation?.resume()
        continuation = nil
    }
}

private struct DismissFixture: View {
    @ObservedObject var model: DismissInputs
    let action: (() async -> Void)?

    var body: some View {
        FlowStack(path: $model.path, dismissAction: action) {
            DismissProbe(model: model)
                .flowDestination(for: String.self) { Text($0) }
        }
    }
}

private struct DismissProbe: View {
    @Environment(\.flowDismiss) private var dismiss
    let model: DismissInputs

    var body: some View {
        Color.clear.onAppear { model.dismiss = dismiss }
    }
}
