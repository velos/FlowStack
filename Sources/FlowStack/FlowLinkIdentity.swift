//
//  FlowLinkIdentity.swift
//

import SwiftUI

/// Tells a flow link apart from any others that present the same value.
enum FlowLinkIdentity: Hashable {
    /// Given with `flowLinkID(_:)`. A link that is recreated comes back with the same one.
    case explicit(AnyHashable)

    /// One instance of a link. A link that is recreated, by a lazy container that let it go or
    /// by a change of layout, comes back as another.
    case instance(ObjectIdentifier)
}

/// Which flow link a destination was presented from, and so which it returns to.
struct FlowLinkSource: Hashable {
    var link: FlowLinkIdentity

    /// The other links presenting the same value when this one was activated. The destination
    /// can't have come from any of them, however long they last.
    var passedOver: Set<FlowLinkIdentity> = []

    /// Whether the destination came from the link with `identity`, as far as can be known.
    ///
    /// An instance of a link that wasn't there to be passed over may be the activated link
    /// itself, recreated since, and is taken to be. Nothing tells it apart from a recreated
    /// link that *was* passed over, which is what an explicit identity is for.
    func includes(_ identity: FlowLinkIdentity) -> Bool {
        if link == identity { return true }
        guard case .instance = link, case .instance = identity else { return false }
        return !passedOver.contains(identity)
    }
}

struct FlowLinkIDKey: EnvironmentKey {
    static let defaultValue: AnyHashable? = nil
}

extension EnvironmentValues {
    var flowLinkID: AnyHashable? {
        get { self[FlowLinkIDKey.self] }
        set { self[FlowLinkIDKey.self] = newValue }
    }
}

public extension View {

    /// Tells apart flow links that present the same value.
    ///
    /// A value can be presented by more than one flow link at once: a product that appears
    /// in a row of featured products and again in the list beneath it, say. A destination
    /// zooms out of the link that was activated and back into that same link, which FlowStack
    /// works out for itself as long as the links stay as they are.
    ///
    /// It can't once the links have *all* been recreated while the destination was presented,
    /// which is what a change of layout does (a rotation, a foldable opening, ...), and what a
    /// lazy container does to links scrolled far out of view. Nothing then says which of the
    /// new links stands where the activated one did. Giving the links different identifiers
    /// settles it:
    ///
    ///     FeaturedProducts(products)      // FlowLink(value: product) { ... }
    ///         .flowLinkID("featured")
    ///     ProductList(products)           // FlowLink(value: product) { ... }
    ///
    /// The identifier only has to differ between links that present the same value, so it can
    /// be given to a single link or, as here, to everything in a section at once.
    ///
    /// To present a value from a particular link yourself, append it to the flow path with
    /// that link's identifier, using `FlowPath.append(_:linkID:)`.
    func flowLinkID<ID: Hashable>(_ id: ID) -> some View {
        environment(\.flowLinkID, AnyHashable(id))
    }
}
