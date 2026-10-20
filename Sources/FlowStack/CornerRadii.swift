//
//  CornerRadii.swift
//

import SwiftUI

/// Per-corner radii expressed in physical (left/right) terms, since the
/// display corners they are matched against don't flip with layout direction.
struct CornerRadii: Equatable {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    static let zero = CornerRadii(uniform: 0)

    init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    init(uniform radius: CGFloat) {
        self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }

    var isUniform: Bool {
        topLeft == topRight && topLeft == bottomLeft && topLeft == bottomRight
    }

    var maximum: CGFloat {
        max(topLeft, topRight, bottomLeft, bottomRight)
    }

    func map(_ transform: (CGFloat) -> CGFloat) -> CornerRadii {
        CornerRadii(
            topLeft: transform(topLeft),
            topRight: transform(topRight),
            bottomLeft: transform(bottomLeft),
            bottomRight: transform(bottomRight)
        )
    }

    /// Each corner's radius interpolated from a shared starting `radius` (at
    /// `percent` 0) to this value (at `percent` 1).
    func interpolated(from radius: CGFloat, percent: CGFloat) -> CornerRadii {
        map { max(0, radius + ($0 - radius) * percent) }
    }
}

extension CornerRadii: Animatable {
    typealias AnimatableData = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>

    var animatableData: AnimatableData {
        get { AnimatablePair(AnimatablePair(topLeft, topRight), AnimatablePair(bottomLeft, bottomRight)) }
        set {
            topLeft = newValue.first.first
            topRight = newValue.first.second
            bottomLeft = newValue.second.first
            bottomRight = newValue.second.second
        }
    }
}

/// A rounded rectangle whose corners can each have a different radius.
struct UnevenCornerShape: Shape {
    var radii: CornerRadii
    var style: RoundedCornerStyle

    var animatableData: CornerRadii.AnimatableData {
        get { radii.animatableData }
        set { radii.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if radii.isUniform {
            return RoundedRectangle(cornerRadius: radii.topLeft, style: style).path(in: rect)
        }

        if #available(iOS 16.0, *) {
            // Built as a Path rather than an UnevenRoundedRectangle, which
            // would mirror the corners in right-to-left layouts.
            let cornerRadii = RectangleCornerRadii(
                topLeading: radii.topLeft,
                bottomLeading: radii.bottomLeft,
                bottomTrailing: radii.bottomRight,
                topTrailing: radii.topRight
            )
            return Path(roundedRect: rect, cornerRadii: cornerRadii, style: style)
        }

        return RoundedRectangle(cornerRadius: radii.maximum, style: style).path(in: rect)
    }
}
