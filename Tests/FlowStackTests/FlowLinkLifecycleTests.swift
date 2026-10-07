import SwiftUI
import XCTest
@testable import FlowStack

@MainActor
final class FlowLinkLifecycleTests: XCTestCase {
    func testRegistrationFollowsValueIdentityAndDepthWithoutResizing() async throws {
        let store = FlowLinkContextStore()
        let model = LinkInputs()
        let host = HostedView(LinkFixture(model: model, store: store))
        defer { host.close() }

        try await waitFor("initial link") { self.context(in: store, value: "before", id: "first", depth: 0) != nil }

        model.value = "after"
        try await waitFor("new value") { self.context(in: store, value: "after", id: "first", depth: 0) != nil }
        XCTAssertNil(store.context(for: AnyHashable("before"), atLevel: 0), "A refreshed row must not remain a return target for its previous value")

        model.linkID = "second"
        try await waitFor("new explicit identity") { self.context(in: store, value: "after", id: "second", depth: 0) != nil }
        XCTAssertNil(context(in: store, value: "after", id: "first", depth: 0))

        model.depth = 1
        try await waitFor("new depth") { self.context(in: store, value: "after", id: "second", depth: 1) != nil }
        XCTAssertNil(store.context(for: AnyHashable("after"), atLevel: 0))

        model.isVisible = false
        try await waitFor("removal of the last registration") { store.context(for: AnyHashable("after"), atLevel: 1) == nil }
    }

    func testIneligibleLinksUnregisterAndCanRegisterAgain() async throws {
        let store = FlowLinkContextStore()
        let model = LinkInputs()
        let host = HostedView(LinkFixture(model: model, store: store))
        defer { host.close() }

        try await waitFor("initial link") { store.context(for: AnyHashable("before"), atLevel: 0) != nil }
        model.value = nil
        try await waitFor("nil value to unregister") { store.context(for: AnyHashable("before"), atLevel: 0) == nil }

        model.value = "before"
        try await waitFor("restored value") { store.context(for: AnyHashable("before"), atLevel: 0) != nil }
        model.animateFromAnchor = false
        try await waitFor("disabled anchor to unregister") { store.context(for: AnyHashable("before"), atLevel: 0) == nil }

        model.animateFromAnchor = true
        try await waitFor("restored anchor") { store.context(for: AnyHashable("before"), atLevel: 0) != nil }
        model.isVisible = false
        try await waitFor("disappearance") { store.context(for: AnyHashable("before"), atLevel: 0) == nil }
        model.isVisible = true
        try await waitFor("recreated link") { store.context(for: AnyHashable("before"), atLevel: 0) != nil }
    }

    private func context(in store: FlowLinkContextStore, value: String, id: String, depth: Int) -> PathContext? {
        store.context(for: AnyHashable(value), atLevel: depth, source: FlowLinkSource(link: .explicit(AnyHashable(id))))
    }
}

private final class LinkInputs: ObservableObject {
    @Published var value: String? = "before"
    @Published var linkID = "first"
    @Published var depth = 0
    @Published var animateFromAnchor = true
    @Published var isVisible = true
}

private struct LinkFixture: View {
    @ObservedObject var model: LinkInputs
    let store: FlowLinkContextStore

    var body: some View {
        Group {
            if model.isVisible {
                FlowLink(value: model.value, configuration: .init(animateFromAnchor: model.animateFromAnchor, transitionFromSnapshot: false)) {
                    Color.red.frame(width: 100, height: 100)
                }
                .flowLinkID(model.linkID)
                .environment(\.flowDepth, model.depth)
            }
        }
        .environment(\.flowLinkContexts, store)
    }
}
