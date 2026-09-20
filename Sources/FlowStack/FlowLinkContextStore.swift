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

    /// Scrolls the scroll views at each depth of the flow stack, where 0 is the root.
    private var scrollProxies: [Int: ScrollViewProxy] = [:]

    /// What to do once a link that had to be scrolled into existence reports in.
    private var pendingReveals: [Key: () -> Void] = [:]

    /// How long to wait for a link to appear after scrolling to it. A lazy container creates
    /// the link within a frame or so; this only runs out when the row can't be found at all,
    /// so it is kept short enough that such a dismissal doesn't feel held up.
    static let revealTimeout: TimeInterval = 0.1

    /// The elements presented when the flow path last changed, for spotting dismissals.
    private var presentedElements: [FlowElement] = []

    /// - Parameter reveal: Scrolls the link fully into view, without animation.
    func update(_ context: PathContext, for key: Key, owner: UUID, reveal: @escaping () -> Void) {
        entries[key] = Entry(owner: owner, context: context, reveal: reveal)

        // This link was scrolled into existence so that a dismissal could return to it.
        let pendingKey = pendingReveals.keys.first { $0.value == key.value && (key.level == nil || $0.level == key.level) }
        if let pendingKey = pendingKey, let completion = pendingReveals.removeValue(forKey: pendingKey) {
            reveal()
            completion()
        }
    }

    func setScrollProxy(_ proxy: ScrollViewProxy, forLevel level: Int) {
        scrollProxies[level] = proxy
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
    ///
    /// A link in a lazy container doesn't exist while it is far outside the visible area,
    /// which is where a layout change can leave it. That link is scrolled to by identity
    /// first, which creates it. `completion` runs once the link exists, so a caller that
    /// waits for it before dismissing finds the link already standing in, hidden, for its
    /// destination, rather than seeing it pop in partway through the dismissal.
    func revealLink(for value: AnyHashable, atLevel level: Int, completion: (() -> Void)? = nil) {
        if let entry = entry(for: value, atLevel: level) {
            entry.reveal()
            completion?()
            return
        }

        guard let proxy = scrollProxies[level] else {
            completion?()
            return
        }

        let key = Key(value: value, level: level)
        pendingReveals[key] = completion ?? {}

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            Self.scroll(proxy, toRowPresenting: value)
        }

        // The value may not be how its row is identified, in which case no link appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealTimeout) { [weak self] in
            self?.pendingReveals.removeValue(forKey: key)?()
        }
    }

    /// Scrolls to the row presenting `value`, by the identifier the row is likely to have in
    /// a `ForEach`: the `id` of an `Identifiable` value, or else the value itself, as in a
    /// `ForEach` over `\.self`.
    ///
    /// The identifier is passed with its concrete type. SwiftUI doesn't match a row whose
    /// identifier is, say, a `String` against an `AnyHashable` wrapping that string.
    static func scroll(_ proxy: ScrollViewProxy, toRowPresenting value: AnyHashable) {
        if let identifiable = value.base as? any Identifiable {
            scroll(proxy, toIdentifierOf: identifiable)
        } else if let hashable = value.base as? any Hashable {
            scroll(proxy, to: hashable)
        }
    }

    private static func scroll<Value: Identifiable>(_ proxy: ScrollViewProxy, toIdentifierOf value: Value) {
        proxy.scrollTo(value.id)
    }

    private static func scroll<Identifier: Hashable>(_ proxy: ScrollViewProxy, to identifier: Identifier) {
        proxy.scrollTo(identifier)
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
