//
//  ScrollReveal.swift
//

import SwiftUI

/// Scrolls the scroll views containing a view so that the view is fully visible.
///
/// An `ObservableObject` only so that a view can hold it in a `StateObject`, which creates it
/// once. It publishes nothing.
final class ScrollRevealController: ObservableObject {

    /// The breathing room kept between the revealed view and the edge of the visible area.
    static let margin: CGFloat = 12

    fileprivate weak var view: UIView?

    /// Moves the view fully into the visible area of every scroll view that contains it,
    /// without animation. The visible area excludes anything covering the scroll view's
    /// edges, like a navigation bar, so a view underneath one is brought out from under it.
    func reveal() {
        // Deferred so that UIKit has the frames for the layout that prompted the reveal.
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.view, view.window != nil else { return }

            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView, scrollView.isScrollEnabled {
                    Self.reveal(view, in: scrollView)
                }
                ancestor = current.superview
            }
        }
    }

    private static func reveal(_ view: UIView, in scrollView: UIScrollView) {
        let offset = contentOffset(
            revealing: view.convert(view.bounds, to: scrollView),
            in: scrollView.bounds,
            insets: scrollView.adjustedContentInset,
            contentSize: scrollView.contentSize
        )

        guard offset != scrollView.contentOffset else { return }
        scrollView.setContentOffset(offset, animated: false)
    }

    /// The content offset that brings `frame` fully into the visible area of a scroll view.
    /// - Parameters:
    ///   - frame: The frame to reveal, in the scroll view's coordinate space.
    ///   - bounds: The scroll view's bounds, whose origin is its current content offset.
    ///   - insets: The scroll view's adjusted content inset.
    ///   - contentSize: The size of the scroll view's content.
    static func contentOffset(revealing frame: CGRect, in bounds: CGRect, insets: UIEdgeInsets, contentSize: CGSize) -> CGPoint {
        let visible = bounds.inset(by: insets).insetBy(dx: margin, dy: margin)

        return CGPoint(
            x: offset(
                bounds.minX,
                revealing: frame.minX...frame.maxX,
                in: visible.minX...max(visible.minX, visible.maxX),
                limits: -insets.left...max(-insets.left, contentSize.width - bounds.width + insets.right)
            ),
            y: offset(
                bounds.minY,
                revealing: frame.minY...frame.maxY,
                in: visible.minY...max(visible.minY, visible.maxY),
                limits: -insets.top...max(-insets.top, contentSize.height - bounds.height + insets.bottom)
            )
        )
    }

    private static func offset(_ offset: CGFloat, revealing frame: ClosedRange<CGFloat>, in visible: ClosedRange<CGFloat>, limits: ClosedRange<CGFloat>) -> CGFloat {
        // The content doesn't scroll along this axis.
        guard limits.upperBound > limits.lowerBound else { return offset }

        var offset = offset
        let frameLength = frame.upperBound - frame.lowerBound
        let visibleLength = visible.upperBound - visible.lowerBound

        // A frame longer than the visible area is aligned to its start.
        if frame.lowerBound < visible.lowerBound || frameLength > visibleLength {
            offset += frame.lowerBound - visible.lowerBound
        } else if frame.upperBound > visible.upperBound {
            offset += frame.upperBound - visible.upperBound
        }

        return min(max(offset, limits.lowerBound), limits.upperBound)
    }
}

/// An invisible view that gives a `ScrollRevealController` a foothold in the UIKit hierarchy.
struct ScrollRevealView: UIViewRepresentable {
    let controller: ScrollRevealController

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        controller.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        controller.view = uiView
    }
}
