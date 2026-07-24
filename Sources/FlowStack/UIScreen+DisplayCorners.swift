//
//  UIScreen+DisplayCorners.swift
//
//  Created by Zac White on 3/16/23.
//

import UIKit

extension UIWindowScene {
    static var firstForegroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive } as? UIWindowScene
    }
}

/// Pulled from https://github.com/kylebshr/ScreenCorners
extension UIScreen {

    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()

    /// The corner radius used when the display's real corner radius can't be
    /// determined, or on square-cornered displays where a small radius still
    /// looks better for presented views.
    private static let fallbackCornerRadius: CGFloat = 12

    private static var cachedDisplayCornerRadius: CGFloat?

    /// The corner radius of the display. Uses a private property of `UIScreen`
    /// and falls back to a sensible default if the API changes.
    static var displayCornerRadius: CGFloat {
        if let cached = cachedDisplayCornerRadius {
            return cached
        }

        // Don't cache the fallback: a lookup that fails because no scene is
        // foreground yet may succeed on a later attempt.
        guard let screen = UIWindowScene.firstForegroundScene?.screen,
              let cornerRadius = screen.value(forKey: cornerRadiusKey) as? CGFloat else {
            return fallbackCornerRadius
        }

        let radius = cornerRadius > 0 ? cornerRadius : fallbackCornerRadius
        cachedDisplayCornerRadius = radius
        return radius
    }
}
