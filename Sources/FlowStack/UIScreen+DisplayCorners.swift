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

    /// The corner radius of the display. Uses a private property of `UIScreen`,
    /// and may report 0 if the API changes.
    static var displayCornerRadius: CGFloat? = {

        guard let screen = UIWindowScene.firstForegroundScene?.screen else {
            return nil
        }

        guard let cornerRadius = screen.value(forKey: cornerRadiusKey) as? CGFloat else {
            return nil
        }

        return cornerRadius > 0 ? cornerRadius : 12
    }()
}
