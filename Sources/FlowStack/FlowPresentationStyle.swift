//
//  FlowPresentationStyle.swift
//

import SwiftUI

/// How a flow stack sizes a presented destination view.
///
/// Set a style with `FlowLink.Configuration`. Destinations presented by
/// appending to a `FlowPath` directly use ``automatic``.
public enum FlowPresentationStyle: Hashable, Sendable, CaseIterable {

    /// Fills the flow stack on iPhone — including wide iPhone displays, like an
    /// unfolded iPhone Duo or a landscape iPhone Pro Max — and behaves like
    /// ``card`` on every other device.
    case automatic

    /// Always fills the flow stack.
    case fullScreen

    /// Presents a centered card over the dimmed flow stack when the flow stack
    /// is wide enough to fit one, and otherwise fills the flow stack.
    case card
}

extension FlowPresentationStyle {

    /// Whether a destination fills the flow stack rather than floating as a card.
    /// - Parameters:
    ///   - cardFits: Whether the flow stack has room to present a card.
    ///   - idiom: The idiom of the device presenting the destination.
    func isFullScreen(cardFits: Bool, idiom: UIUserInterfaceIdiom) -> Bool {
        switch self {
        case .fullScreen:
            return true
        case .card:
            return !cardFits
        case .automatic:
            return !cardFits || idiom == .phone
        }
    }
}
