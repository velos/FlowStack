import SwiftUI
import XCTest
@testable import FlowStack

@available(iOS 16.0, *)
@MainActor
final class DismissalRevealTests: XCTestCase {
    /// A link has a single view to reveal it from, even while it is being swapped for the
    /// stand-in that holds its place as its destination is presented. A second one, made for
    /// the stand-in, could leave the link holding the view that goes away with the link it
    /// replaced, and with nothing to reveal it from as the destination is dismissed.
    func testALinkKeepsOneViewToRevealItFromWhileItsDestinationIsPresented() async throws {
        let model = BarredLinksModel()
        let host = HostedView(BarredLinks(model: model))
        defer { host.close() }
        let root: UIView = host.controller.view

        let target = try await linkTuckedUnderTheBar(in: root, model: model)
        try await press(target, in: root)
        try await waitFor("the destination") { model.path.count == 1 }

        XCTAssertEqual(revealViews(over: target, in: root), 1)
    }

    /// A link that is partly under a bar is brought out from under it as its destination is
    /// dismissed, including by a dismissal started from asynchronous code, which runs before
    /// SwiftUI has updated the link for the destination leaving.
    func testDismissalFromAsyncCodeRevealsALinkUnderABar() async throws {
        let model = BarredLinksModel()
        let host = HostedView(BarredLinks(model: model))
        defer { host.close() }
        let root: UIView = host.controller.view

        let target = try await linkTuckedUnderTheBar(in: root, model: model)
        let scrollView = try XCTUnwrap(scrollView(in: root))
        try await press(target, in: root)
        try await waitFor("the destination") { model.path.count == 1 }
        try await Task.sleep(nanoseconds: 800_000_000)

        model.dismiss?()

        try await waitFor("the dismissal") { model.path.isEmpty }
        try await waitFor("the link clear of the bar") {
            let current = self.target(in: root)
            return current.map { self.isClearOfBar($0, in: scrollView) } ?? false
        }
    }

    /// Scrolls the target link part of the way under the bar, and returns it.
    private func linkTuckedUnderTheBar(in root: UIView, model: BarredLinksModel) async throws -> UIView {
        try await waitFor("the links and the dismiss action") {
            model.dismiss != nil && self.scrollView(in: root) != nil && self.target(in: root) != nil
        }
        let scrollView = try XCTUnwrap(scrollView(in: root))
        let target = try XCTUnwrap(target(in: root))

        let frame = target.convert(target.bounds, to: scrollView)
        scrollView.setContentOffset(CGPoint(x: 0, y: frame.minY - scrollView.adjustedContentInset.top + 60), animated: false)
        try await waitFor("the link under the bar") { !self.isClearOfBar(target, in: scrollView) }
        return target
    }

    /// Presses the link with its own button, as a tap would.
    private func press(_ target: UIView, in root: UIView) async throws {
        let button = try XCTUnwrap(linkButton(over: target, in: root))
        let press = try XCTUnwrap(button.allTargets.lazy.compactMap { $0 as? GestureContainer.Coordinator }.first)
        press.onEnter()
        try await Task.sleep(nanoseconds: 100_000_000)
        press.onTouchUpInside()
    }

    private func isClearOfBar(_ view: UIView, in scrollView: UIScrollView) -> Bool {
        let visible = scrollView.bounds.inset(by: scrollView.adjustedContentInset)
        return view.window != nil && visible.contains(view.convert(view.bounds, to: scrollView))
    }

    /// The button a flow link lays over its label.
    private func linkButton(over target: UIView, in root: UIView) -> UIButton? {
        guard let window = target.window else { return nil }
        let point = target.convert(CGPoint(x: target.bounds.midX, y: target.bounds.maxY - 20), to: window)
        func find(_ view: UIView) -> UIButton? {
            if let button = view as? UIButton, button.allTargets.contains(where: { $0 is GestureContainer.Coordinator }),
               button.convert(button.bounds, to: window).contains(point) {
                return button
            }
            return view.subviews.lazy.compactMap { find($0) }.first
        }
        return find(root)
    }

    /// How many of the views that links are revealed from lie over the target link.
    private func revealViews(over target: UIView, in root: UIView) -> Int {
        guard let window = target.window else { return 0 }
        let point = target.convert(CGPoint(x: target.bounds.midX, y: target.bounds.midY), to: window)
        func count(_ view: UIView) -> Int {
            let isOver = view is ScrollRevealAnchorView && view.window != nil && view.convert(view.bounds, to: window).contains(point)
            return (isOver ? 1 : 0) + view.subviews.reduce(0) { $0 + count($1) }
        }
        return count(root)
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView, scrollView.contentSize.height > scrollView.bounds.height { return scrollView }
        return view.subviews.lazy.compactMap { self.scrollView(in: $0) }.first
    }

    private func target(in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == "barred-target", view.window != nil { return view }
        return view.subviews.lazy.compactMap { self.target(in: $0) }.first
    }
}

private final class BarredLinksModel: ObservableObject {
    @Published var path = FlowPath()
    var dismiss: FlowDismissAction?
}

private struct BarredRow: Identifiable, Hashable {
    let id: Int
}

/// Links in a navigation stack, scrolling under a bar of the app's own.
@available(iOS 16.0, *)
private struct BarredLinks: View {
    @ObservedObject var model: BarredLinksModel

    var body: some View {
        FlowStack(path: $model.path) {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach((0..<8).map(BarredRow.init)) { row in
                            FlowLink(value: row, configuration: .init(cornerRadius: 24)) {
                                BarredRowLabel(row: row).frame(height: 240)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.red.frame(height: 100)
                }
            }
            .background(DismissProbe(model: model))
            .flowDestination(for: BarredRow.self) { row in
                Text("Row \(row.id)").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white)
            }
        }
    }
}

private struct DismissProbe: View {
    @Environment(\.flowDismiss) private var dismiss
    let model: BarredLinksModel

    var body: some View {
        Color.clear.onAppear { model.dismiss = dismiss }
    }
}

private struct BarredRowLabel: UIViewRepresentable {
    let row: BarredRow

    func makeUIView(context: Context) -> UILabel { UILabel() }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = "Row \(row.id)"
        label.accessibilityIdentifier = row.id == 2 ? "barred-target" : nil
    }
}
