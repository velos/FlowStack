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
///
/// An `ObservableObject` only so that a view can hold it in a `StateObject`, which creates it
/// once. It publishes nothing: a transition reads it as it renders.
final class FlowLinkContextStore: ObservableObject {

    struct Key: Hashable {
        let value: AnyHashable
        /// The depth of the link in the flow stack, or `nil` for a link that isn't tied to one.
        let level: Int?
    }

    private struct Entry {
        let identity: FlowLinkIdentity
        let owner: ObjectIdentifier
        /// Counts up as links report in for the first time, so a later link has a higher one.
        let sequence: Int
        var context: PathContext
        var reveal: () -> Void
        var prepareSnapshot: () -> Void
    }

    /// More than one link can present the same value, each with its own identity.
    private var entries: [Key: [Entry]] = [:]
    private var nextSequence = 0

    /// Scrolls the scroll views at each depth of the flow stack, where 0 is the root.
    private var scrollProxies: [Int: ScrollViewProxy] = [:]

    /// What to do once a link that had to be scrolled into existence reports in.
    private var pendingReveals: [Key: PendingReveal] = [:]

    private struct PendingReveal {
        var source: FlowLinkSource?
        var completion: () -> Void
    }

    /// How long to wait for a link to appear after scrolling to it. A lazy container creates
    /// the link within a frame or so; this only runs out when the row can't be found at all,
    /// so it is kept short enough that such a dismissal doesn't feel held up.
    static let revealTimeout: TimeInterval = 0.1

    /// The elements presented when the flow path last changed, for spotting dismissals.
    private var presentedElements: [FlowElement] = []

    /// The dismissals that revealed their link before they began, and so needn't again.
    private var revealedDismissals: Set<Key> = []

    /// - Parameters:
    ///   - identity: Tells the link apart from any others presenting the same value. An
    ///     instance of the link, unless it was given an identifier.
    ///   - owner: The instance of the link, which is the only one that can remove it again.
    ///   - reveal: Scrolls the link fully into view, without animation.
    ///   - prepareSnapshot: Takes a snapshot of the link if it doesn't have a current one.
    ///     This lays out a view, so it must not be called during a view update.
    func update(_ context: PathContext, for key: Key, identity: FlowLinkIdentity? = nil, owner: ObjectIdentifier, reveal: @escaping () -> Void, prepareSnapshot: @escaping () -> Void = {}) {
        let identity = identity ?? .instance(owner)

        // A link with an identifier that has been recreated takes over from the one it was.
        let existing = entries[key]?.firstIndex { $0.identity == identity }
        let sequence: Int
        if let previous = existing.flatMap({ entries[key]?[$0] }), previous.owner == owner {
            sequence = previous.sequence
        } else {
            sequence = nextSequence
            nextSequence += 1
        }

        let entry = Entry(identity: identity, owner: owner, sequence: sequence, context: context, reveal: reveal, prepareSnapshot: prepareSnapshot)
        if let existing = existing {
            entries[key]?[existing] = entry
        } else {
            entries[key, default: []].append(entry)
        }

        // This link was scrolled into existence so that a dismissal could return to it.
        let pendingKey = pendingReveals.first { pending in
            pending.key.value == key.value && (key.level == nil || pending.key.level == key.level) &&
                pending.value.source?.includes(identity) ?? true
        }?.key
        if let pendingKey = pendingKey, let completion = pendingReveals.removeValue(forKey: pendingKey)?.completion {
            reveal()

            // A link that has only just been created has no snapshot for the dismissal to
            // end on. It reports in during a view update, and doesn't know its size until
            // that update is over, so its snapshot waits for the next pass of the run loop.
            DispatchQueue.main.async {
                prepareSnapshot()
                completion()
            }
        }
    }

    func setScrollProxy(_ proxy: ScrollViewProxy, forLevel level: Int) {
        scrollProxies[level] = proxy
    }

    /// Removes the entry for `key`, unless another link has since taken it over. When a
    /// layout swaps containers, the replacement link registers before the old one disappears.
    func remove(_ key: Key, owner: ObjectIdentifier) {
        entries[key]?.removeAll { $0.owner == owner }
        if entries[key]?.isEmpty == true {
            entries[key] = nil
        }
    }

    /// - Parameter source: The link the value was presented from, where that is known.
    func context(for value: AnyHashable, atLevel level: Int, source: FlowLinkSource? = nil) -> PathContext? {
        entry(for: value, atLevel: level, source: source)?.context
    }

    /// The links presenting the same value as the link with `key`, other than `identity`.
    /// These are what a destination presented from that link did *not* come from.
    func identities(presentingSameValueAs key: Key, otherThan identity: FlowLinkIdentity) -> Set<FlowLinkIdentity> {
        // A link that isn't tied to a depth of the flow stack can stand in at any of them.
        let rivals = entries.filter { $0.key.value == key.value && (key.level == nil || $0.key.level == nil || $0.key.level == key.level) }
        return Set(rivals.values.joined().map(\.identity)).subtracting([identity])
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
    func revealLink(for value: AnyHashable, atLevel level: Int, source: FlowLinkSource? = nil, completion: (() -> Void)? = nil) {
        if completion != nil {
            revealedDismissals.insert(Key(value: value, level: level))
        }

        if let entry = entry(for: value, atLevel: level, source: source) {
            entry.reveal()
            entry.prepareSnapshot()
            completion?()
            return
        }

        guard let proxy = scrollProxies[level] else {
            completion?()
            return
        }

        let key = Key(value: value, level: level)
        pendingReveals[key] = PendingReveal(source: source, completion: completion ?? {})

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            Self.scroll(proxy, toRowPresenting: value)
        }

        // The value may not be how its row is identified, in which case no link appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealTimeout) { [weak self] in
            self?.pendingReveals.removeValue(forKey: key)?.completion()
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
        // A dismissal started by FlowDismissAction has revealed its link already. One that
        // wasn't, like an adopter removing from its own path, is first heard of here.
        let dismissed = presentedElements.filter { element in
            !elements.contains(element) && revealedDismissals.remove(Key(value: AnyHashable(element.value), level: element.index)) == nil
        }
        presentedElements = elements

        // A destination's scroll proxy is of no use once the destination is gone.
        scrollProxies = scrollProxies.filter { $0.key <= elements.count }

        // This runs during a view update, which is no place to take a snapshot, and the
        // dismissal is already under way, so there is nothing to hold up by deferring it.
        DispatchQueue.main.async { [weak self] in
            for element in dismissed {
                self?.revealLink(for: AnyHashable(element.value), atLevel: element.index, source: element.source)
            }
        }
    }

    /// The link a destination presenting `value` returns to.
    ///
    /// That is the link it was presented from, for as long as that link lasts. After that it
    /// is the latest link that could be the same one recreated. A destination that wasn't
    /// presented from a link at all returns to the latest link that presents its value.
    private func entry(for value: AnyHashable, atLevel level: Int, source: FlowLinkSource?) -> Entry? {
        for key in [Key(value: value, level: level), Key(value: value, level: nil)] {
            guard let candidates = entries[key], !candidates.isEmpty else { continue }
            guard let source = source else {
                return candidates.max { $0.sequence < $1.sequence }
            }

            let entry = candidates.first { $0.identity == source.link } ??
                candidates.filter { source.includes($0.identity) }.max { $0.sequence < $1.sequence }
            if let entry = entry {
                return entry
            }
        }
        return nil
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
