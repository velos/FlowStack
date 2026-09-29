//
//  FlowTransition.swift
//
//  Created by Zac White on 2/23/23.
//

import Foundation
import SwiftUI

extension EnvironmentValues {
    var opacityTransitionPercent: CGFloat {
        get { return self[OpacityTransitionKey.self] }
        set { self[OpacityTransitionKey.self] = newValue }
    }
}

struct OpacityTransitionKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// An action that dismisses the current presented view.
public struct FlowDismissAction {
    var onDismiss: () -> Void = { }

    public func callAsFunction() {
        onDismiss()
    }
}

public extension EnvironmentValues {
    var flowDismiss: FlowDismissAction {
        get { return self[FlowDismissActionKey.self] }
        set { self[FlowDismissActionKey.self] = newValue }
    }
}

struct FlowDismissActionKey: EnvironmentKey {
    static let defaultValue: FlowDismissAction = .init()
}

extension AnyTransition {

    static func flowTransition(with context: PathContext?, source: FlowLinkSource?, value: AnyHashable, level: Int) -> AnyTransition {
        AnyTransition.modifier(
            active: FlowPresentModifier(percent: 0, context: context, source: source, value: value, level: level),
            identity: FlowPresentModifier(percent: 1, context: context, source: source, value: value, level: level)
        )
    }

    struct OpacityPercentModifier: AnimatableModifier {
        var percent: Double

        var animatableData: Double {
            get { percent }
            set { percent = newValue }
        }

        func body(content: Content) -> some View {
            content
                .opacity(percent)
                .environment(\.opacityTransitionPercent, percent)
        }
    }

    /// Keeps a view hidden for as long as it is transitioning in, and hides it the
    /// moment it starts transitioning out.
    struct VisibleOnceSettledModifier: Animatable, ViewModifier {
        var percent: Double

        /// Springs overshoot their target and ring around it, so a threshold of exactly 1
        /// would flicker. The view is indistinguishable from settled just short of it.
        static let threshold: Double = 0.97

        var animatableData: Double {
            get { percent }
            set { percent = newValue }
        }

        func body(content: Content) -> some View {
            content
                .opacity(percent >= Self.threshold ? 1 : 0)
        }
    }

    static var visibleOnceSettled: AnyTransition {
        AnyTransition.modifier(
            active: VisibleOnceSettledModifier(percent: 0),
            identity: VisibleOnceSettledModifier(percent: 1)
        )
    }

    /// Stops a view from taking touches while it is being removed. A view stays in the
    /// hierarchy until its removal has finished animating, in the way of whatever is beneath.
    struct HitTestingModifier: ViewModifier {
        var isEnabled: Bool

        func body(content: Content) -> some View {
            content.allowsHitTesting(isEnabled)
        }
    }

    static var untouchable: AnyTransition {
        AnyTransition.modifier(
            active: HitTestingModifier(isEnabled: false),
            identity: HitTestingModifier(isEnabled: true)
        )
    }

    static var opacityPercent: AnyTransition {
        AnyTransition.modifier(
            active: OpacityPercentModifier(percent: 0),
            identity: OpacityPercentModifier(percent: 1)
        )
    }

    struct FlowPresentModifier: Animatable, ViewModifier {
        var percent: CGFloat
        /// The context captured when the flow link was activated, or `nil` for a
        /// destination that was appended to the flow path directly.
        var context: PathContext?
        /// The flow link the destination was presented from, where that is known.
        var source: FlowLinkSource?
        var value: AnyHashable
        var level: Int

        @Environment(\.flowLinkContexts) private var linkContexts
        @Environment(\.flowPath) private var flowPath

        /// Whether the destination is still in the flow path, as opposed to on its way out.
        ///
        /// A destination being dismissed stays in the view hierarchy until its transition has
        /// finished, which for a spring means until it has fully settled, well after it looks
        /// done. All that time it would take touches meant for the flow stack beneath it, and
        /// not only where it appears to be: a destination hosted in UIKit is hit-tested by its
        /// container, which still fills the flow stack after the destination has shrunk.
        private var isPresented: Bool {
            flowPath?.wrappedValue.contains(value, atLevel: level) ?? true
        }

        /// The transition is captured when the destination is inserted, so `context`
        /// describes where the link was then. Resolving against the link's latest report
        /// each time the view renders lets a dismissal find the link where it is now. A
        /// destination appended directly adopts the context of a matching link, if any.
        private var resolvedContext: PathContext {
            guard let live = linkContexts?.context(for: value, atLevel: level, source: source) else { return context ?? .init() }
            guard var resolved = context else { return live }
            resolved.anchor = live.anchor
            resolved.overrideAnchor = live.overrideAnchor

            // A link retakes its snapshots when its layout changes, so its own are the ones
            // that show it as it is now. It has none if it doesn't transition from a snapshot.
            if !live.snapshotDict.isEmpty {
                resolved.snapshotDict = live.snapshotDict
                resolved.snapshot = live.snapshot
            }
            return resolved
        }

        @State private var panOffset: CGPoint = .zero
        @State private var isDisabled: Bool = false
        @State private var isDismissing: Bool = false
        @State private var snapCornerRadiusZero: Bool = true

        @Environment(\.colorScheme) private var colorScheme

        private var snapshotPercent: CGFloat {
            max(0, 1 - percent / 0.2)
        }

        @Environment(\.flowDismiss) private var dismiss
        @Environment(\.flowTransaction) private var transaction
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass

        private var activeSnapshot: UIImage? {
            resolvedContext.snapshotDict[colorScheme] ?? resolvedContext.snapshot
        }

        private func isPresentedFullscreen(availableSize: CGSize) -> Bool {
            let cardFits = horizontalSizeClass == .regular && availableSize.width - 2 * Constants.minVerticalPadding >= Constants.maxWidth
            return resolvedContext.presentationStyle.isFullScreen(cardFits: cardFits, idiom: UIDevice.current.userInterfaceIdiom)
        }

        /// The corner radii of the fully presented view, which the transition
        /// animates toward from the flow link's corner radius.
        private func presentedCornerRadii(with proxy: GeometryProxy) -> CornerRadii {
            // The display's corner radius only suits a view whose corners sit on
            // the display's corners. Anything floating away from them gets a
            // sheet-like radius instead, which on displays with very round
            // corners is considerably smaller.
            let floatingRadius = min(UIScreen.displayCornerRadius, Constants.maxFloatingCornerRadius)

            guard isPresentedFullscreen(availableSize: proxy.size) else {
                return CornerRadii(uniform: floatingRadius)
            }

            #if compiler(>=6.4)
            // Displays can have a different radius at each corner (e.g. the
            // hinge side of a foldable), which a single value can't describe.
            if #available(iOS 27.0, *), let radii = proxy.concentricCornerRadii {
                // A corner resolves to zero when it isn't near a corner of the container.
                return CornerRadii(
                    topLeft: radii.topLeading,
                    topRight: radii.topTrailing,
                    bottomLeft: radii.bottomLeading,
                    bottomRight: radii.bottomTrailing
                ).map { $0 > 0 ? $0 : floatingRadius }
            }
            #endif

            return CornerRadii(uniform: UIScreen.displayCornerRadius)
        }

        private func cornerRadii(with proxy: GeometryProxy) -> CornerRadii {
            // At rest a fullscreen view is clipped by the display itself.
            if isPresentedFullscreen(availableSize: proxy.size), percent >= 1, snapCornerRadiusZero {
                return .zero
            }

            return presentedCornerRadii(with: proxy).interpolated(from: resolvedContext.cornerRadius, percent: percent)
        }

        var cornerStyle: RoundedCornerStyle { percent > 0.5 ? .continuous : resolvedContext.cornerStyle }

        var animatableData: CGFloat {
            get { percent }
            set { percent = newValue }
        }

        func zoomRect(with proxy: GeometryProxy, anchor: Anchor<CGRect>?, percent: CGFloat, pullOffset: CGPoint?) -> CGRect {
            let rect: CGRect
            if let anchor = anchor {
                rect = proxy[anchor]
            } else {
                rect = proxy.frame(in: .global)
                    .insetBy(dx: 50, dy: 100)
                    .offsetBy(dx: 0, dy: 0)
            }

            let pullPercent = (1 - (0.9 + (0.1 * (1 - min(1, max(0, (pullOffset ?? .zero).y / 200))))))

            let zoomRect = CGRect(
                x: (proxy.size.width / 2) * percent + rect.midX * (1 - percent) + (pullOffset ?? .zero).x / 3,
                y: (proxy.size.height / 2) * percent + rect.midY * (1 - percent) + (pullOffset ?? .zero).y / 3,
                width: rect.width + ((presentationSize(availableSize: proxy.size).width - rect.width) * max(0, percent) * (1 - pullPercent)),
                height: rect.height + ((presentationSize(availableSize: proxy.size).height - rect.height) * max(0, percent) * (1 - pullPercent))
            )

            return zoomRect
        }

        struct Constants {
            static let maxWidth: CGFloat = 706
            static let maxHeight: CGFloat = 998
            static let minVerticalPadding: CGFloat = 44
            /// Matches the corner radius of system sheets.
            static let maxFloatingCornerRadius: CGFloat = 40
        }

        private func presentationSize(availableSize: CGSize) -> CGSize {

            if isPresentedFullscreen(availableSize: availableSize) {
                return availableSize
            } else {
                let width = Constants.maxWidth
                let height = min(Constants.maxHeight, availableSize.height - Constants.minVerticalPadding * 2)
                return CGSize(width: width, height: height)
            }
        }

        func body(content: Content) -> some View {
            // The keyboard is only ignored by a destination that fills the flow stack. That one
            // stays full size behind the keyboard, as any full-screen view does, and its content
            // keeps clear of the keyboard by its own safe area; were it shrunk to end at the
            // keyboard instead, whatever is behind it would show through the keyboard, which is
            // translucent from iOS 26. A card is laid out above the keyboard, so that it moves
            // up out of the keyboard's way like a form sheet. Whether it fills the flow stack
            // depends only on the width, which the keyboard never changes, so it is measured
            // here, outside the keyboard. Ignoring the keyboard alone would stop the destination
            // short of the bottom edge by the home indicator's inset, which the keyboard covers,
            // so a full-screen destination ignores that too.
            GeometryReader { container in
                GeometryReader { proxy in
                    presentation(of: content, in: proxy)
                }
                .ignoresSafeArea(isPresentedFullscreen(availableSize: container.size) ? .all : [], edges: .all)
            }
            .ignoresSafeArea(.container, edges: .all)
            .allowsHitTesting(isPresented)
        }

        @ViewBuilder
        private func presentation(of content: Content, in proxy: GeometryProxy) -> some View {
            let zoomRect = zoomRect(with: proxy, anchor: resolvedContext.overrideAnchor ?? resolvedContext.anchor, percent: percent, pullOffset: panOffset)
            let scaleRatio = resolvedContext.shouldScaleHorizontally ? zoomRect.size.width / proxy.size.width : 1.0

            content
                .onInteractiveDismissGesture(threshold: 80, isEnabled: !isDisabled, isDismissing: isDismissing, swipeUpToDismiss: resolvedContext.swipeUpToDismiss, onDismiss: {
                    guard !isDisabled else { return }
                    dismiss()
                    isDismissing = true
                }, onPan: { offset in
                    guard !isDisabled else { return }
                    if snapCornerRadiusZero {
                        // The pull is just starting, so the destination still covers
                        // its link. Waiting for the release would move the link in
                        // plain sight behind the shrunken destination.
                        linkContexts?.revealLink(for: value, atLevel: level, source: source)
                    }
                    self.snapCornerRadiusZero = false
                    self.panOffset = offset
                }, onEnded: { _ in
                    // TODO: FS-34: Handle snap corner radius 0 on interactive dismiss cancel
                    withTransaction(transaction) {
                        panOffset = .zero
                    }
                })
                .onPreferenceChange(InteractiveDismissDisabledKey.self) { isDisabled in
                    self.isDisabled = isDisabled
                }
                .overlay(alignment: .top) {
                    if let image = activeSnapshot, percent < 1 {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .opacity(snapshotPercent)
                    }
                }
                .clipShape(UnevenCornerShape(radii: cornerRadii(with: proxy).map { $0 / scaleRatio }, style: cornerStyle))
                .shadow(color: resolvedContext.shadowColor ?? .clear, radius: resolvedContext.shadowRadius, x: resolvedContext.shadowOffset.x, y: resolvedContext.shadowOffset.y)
                .frame(
                    width: resolvedContext.shouldScaleHorizontally ? proxy.size.width : zoomRect.size.width,
                    height: zoomRect.size.height / scaleRatio
                )
                .scaleEffect(x: scaleRatio, y: scaleRatio, anchor: .center)
                .transformEffect(.init(translationX: resolvedContext.anchor == nil ? (1 - percent) * proxy.size.width : 0, y: 0))
                .position(
                    x: zoomRect.origin.x,
                    y: zoomRect.origin.y
                )
                .opacity(resolvedContext.anchor == nil ? percent : 1)
        }
    }
}
