import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class LazyLinkRevealTests: XCTestCase {
    func testRevealCreatesAndScrollsToAnOffscreenIdentifiableValue() async throws {
        let store = FlowLinkContextStore()
        let host = HostedView(LazyLinks(store: store))
        defer { host.close() }
        let target = Row(id: 120)
        try await waitFor("initial rows") { store.context(for: AnyHashable(Row(id: 0)), atLevel: 0) != nil }
        XCTAssertNil(store.context(for: AnyHashable(target), atLevel: 0), "Start with a row the lazy container has not created")

        var completed = false
        store.revealLink(for: AnyHashable(target), atLevel: 0) { completed = true }
        // Do not assert that creation beats the production reveal timeout: that is a
        // scheduling/animation detail. Assert the real scroll and completion outcomes.
        try await waitFor("lazy target and reveal completion") {
            completed && store.context(for: AnyHashable(target), atLevel: 0) != nil &&
                self.targetIsVisible(in: host.controller.view)
        }
    }

    private func targetIsVisible(in root: UIView) -> Bool {
        guard let target = targetView(in: root), let window = target.window else { return false }
        let rect = target.convert(target.bounds, to: window)
        return rect.height > 0 && window.bounds.inset(by: window.safeAreaInsets).contains(rect)
    }

    private func targetView(in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == "lazy-target" { return view }
        return view.subviews.compactMap { targetView(in: $0) }.first
    }
}

private struct Row: Identifiable, Hashable {
    let id: Int
}

private struct LazyLinks: View {
    let store: FlowLinkContextStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    ForEach((0..<150).map(Row.init)) { row in
                        FlowLink(value: row, configuration: .init(transitionFromSnapshot: false)) {
                            RowLabel(row: row).frame(height: 80)
                        }
                    }
                }
            }
            .onAppear { store.setScrollProxy(proxy, forLevel: 0) }
        }
        .environment(\.flowLinkContexts, store)
    }
}

private struct RowLabel: UIViewRepresentable {
    let row: Row

    func makeUIView(context: Context) -> UILabel { UILabel() }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = "Row \(row.id)"
        label.accessibilityIdentifier = row.id == 120 ? "lazy-target" : nil
    }
}
