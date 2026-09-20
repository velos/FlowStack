//
//  FlowLinkContextStore.swift
//

import SwiftUI

/// The latest context reported by each flow link in a flow stack.
///
/// A flow transition is captured when its destination is inserted, so the
/// context stored in the flow path describes where the link was when it was
/// activated. Links keep this store current instead, which lets a transition
/// resolve where its link is *now* — after a rotation, a foldable opening, or
/// any other layout change that happens while the destination is presented.
final class FlowLinkContextStore {

    struct Key: Hashable {
        let value: AnyHashable
        /// The depth of the link in the flow stack, or `nil` for a link that isn't tied to one.
        let level: Int?
    }

    private struct Entry {
        let owner: UUID
        var context: PathContext
        var reveal: () -> Void
    }

    private var entries: [Key: Entry] = [:]

    /// The elements presented when the flow path last changed, for spotting dismissals.
    private var presentedElements: [FlowElement] = []

    /// - Parameter reveal: Scrolls the link fully into view, without animation.
    func update(_ context: PathContext, for key: Key, owner: UUID, reveal: @escaping () -> Void) {
        entries[key] = Entry(owner: owner, context: context, reveal: reveal)
    }

    /// Removes the entry for `key`, unless another link has since taken it over. When a
    /// layout swaps containers, the replacement link registers before the old one disappears.
    func remove(_ key: Key, owner: UUID) {
        guard entries[key]?.owner == owner else { return }
        entries[key] = nil
    }

    func context(for value: AnyHashable, atLevel level: Int) -> PathContext? {
        entry(for: value, atLevel: level)?.context
    }

    /// Scrolls the link presenting `value` fully into view, so that a dismissal has
    /// somewhere visible to return to. The link may have been scrolled partly out of
    /// view, tucked under a navigation bar, or moved by a layout change since it was
    /// activated. This only ever happens as a destination is dismissed, never as it
    /// is presented, where shifting the link would disturb the zoom out of it.
    func revealLink(for value: AnyHashable, atLevel level: Int) {
        entry(for: value, atLevel: level)?.reveal()
    }

    /// Reveals the links of any elements that have left the flow path.
    func pathDidChange(to elements: [FlowElement]) {
        let dismissed = presentedElements.filter { !elements.contains($0) }
        presentedElements = elements

        for element in dismissed {
            revealLink(for: AnyHashable(element.value), atLevel: element.index)
        }
    }

    private func entry(for value: AnyHashable, atLevel level: Int) -> Entry? {
        entries[Key(value: value, level: level)] ?? entries[Key(value: value, level: nil)]
    }
}

struct FlowLinkContextStoreKey: EnvironmentKey {
    static let defaultValue: FlowLinkContextStore? = nil
}

extension EnvironmentValues {
    var flowLinkContexts: FlowLinkContextStore? {
        get { self[FlowLinkContextStoreKey.self] }
        set { self[FlowLinkContextStoreKey.self] = newValue }
    }
}
