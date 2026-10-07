import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class DismissDisabledTests: XCTestCase {
    /// A destination that disables interactive dismissal can't be pulled away.
    func testADestinationThatDisablesInteractiveDismissalCantBePulledAway() async throws {
        let model = DismissDisabledModel()
        let host = HostedView(DismissDisabledStack(model: model))
        defer { host.close() }
        let root: UIView = host.controller.view

        withAnimation(.defaultFlow) { model.path.append(1) }
        try await waitFor("the pull's gestures") { !self.pullGestures(in: root).isEmpty }
        try await waitFor("the pull disabled") { self.pullGestures(in: root).allSatisfy { !$0.isEnabled } }

        model.isDisabled = false
        try await waitFor("the pull enabled") { self.pullGestures(in: root).allSatisfy(\.isEnabled) }
    }

    private func pullGestures(in view: UIView) -> [UIGestureRecognizer] {
        let own = (view.gestureRecognizers ?? []).filter { $0.delegate is InteractiveDismissCoordinator }
        return own + view.subviews.flatMap { pullGestures(in: $0) }
    }
}

private final class DismissDisabledModel: ObservableObject {
    @Published var path = FlowPath()
    @Published var isDisabled = true
}

private struct DismissDisabledStack: View {
    @ObservedObject var model: DismissDisabledModel

    var body: some View {
        FlowStack(path: $model.path) {
            Color.white
                .flowDestination(for: Int.self) { _ in
                    DismissDisabledDestination(model: model)
                }
        }
    }
}

private struct DismissDisabledDestination: View {
    @ObservedObject var model: DismissDisabledModel

    var body: some View {
        Color.blue.flowInteractiveDismissDisabled(model.isDisabled)
    }
}
