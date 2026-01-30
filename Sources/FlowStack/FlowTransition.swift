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

    static func flowTransition(with context: PathContext) -> AnyTransition {
        AnyTransition.modifier(
            active: FlowPresentModifier(percent: 0, context: context),
            identity: FlowPresentModifier(percent: 1, context: context)
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

    static var opacityPercent: AnyTransition {
        AnyTransition.modifier(
            active: OpacityPercentModifier(percent: 0),
            identity: OpacityPercentModifier(percent: 1)
        )
    }

    struct FlowPresentModifier: Animatable, ViewModifier {
        var percent: CGFloat
        var context: PathContext

        @State var panOffset: CGPoint = .zero
        @State var isEnded: Bool = false
        @State private var isDisabled: Bool = false
        @State var isDismissing: Bool = false
        @State private var snapCornerRadiusZero: Bool = true
        @State private var availableSize: CGSize = .zero

        private var snapshotPercent: CGFloat {
            max(0, 1 - percent / 0.2)
        }

        @Environment(\.flowDismiss) var dismiss
        @Environment(\.flowTransaction) var transaction
        @Environment(\.horizontalSizeClass) var horizontalSizeClass

        var cornerRadius: CGFloat { context.cornerRadius + ((UIScreen.displayCornerRadius ?? 20) - context.cornerRadius) * percent }

        var isPresentedFullscreen: Bool {
            horizontalSizeClass == .compact || availableSize.width - 2 * Constants.minVerticalPadding < Constants.maxWidth
        }

        var conditionalCornerRadius: CGFloat {
            if isPresentedFullscreen {
                if percent >= 1 {
                    if snapCornerRadiusZero {
                        return 0
                    } else {
                        return cornerRadius
                    }
                } else {
                    return cornerRadius
                }
            } else {
                return cornerRadius
            }
        }

        var cornerStyle: RoundedCornerStyle { percent > 0.5 ? .continuous : context.cornerStyle }

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
        }

        private func presentationSize(availableSize: CGSize) -> CGSize {

            if horizontalSizeClass == .regular && availableSize.width - 2 * Constants.minVerticalPadding >= Constants.maxWidth {
                let width = Constants.maxWidth
                let height = min(Constants.maxHeight, availableSize.height - Constants.minVerticalPadding * 2)
                return CGSize(width: width, height: height)
            } else {
                return availableSize
            }
        }

        func body(content: Content) -> some View {
            GeometryReader { proxy in
                let zoomRect = zoomRect(with: proxy, anchor: context.overrideAnchor ?? context.anchor, percent: percent, pullOffset: panOffset)
                let scaleRatio = context.shouldScaleHorizontally ? zoomRect.size.width / proxy.size.width : 1.0

                content
                    .onInteractiveDismissGesture(threshold: 80, isEnabled: !isDisabled, isDismissing: isDismissing, swipeUpToDismiss: context.swipeUpToDismiss, onDismiss: {
                        defer { isDismissing = true }
                        guard !isDisabled else { return }
                        dismiss()
                        isDismissing = true
                    }, onPan: { offset in
                        defer { self.isEnded = false }
                        guard !isDisabled else { return }
                        self.snapCornerRadiusZero = false
                        self.panOffset = offset
                    }, onEnded: { isDismissing in
                        // TODO: FS-34: Handle snap corner radius 0 on interactive dismiss cancel
                        withTransaction(transaction) {
                            panOffset = .zero
                            isEnded = true
                        }
                    })
                    .onPreferenceChange(InteractiveDismissDisabledKey.self) { isDisabled in
                        self.isDisabled = isDisabled
                    }
                    .preference(key: SizePreferenceKey.self, value: proxy.size)
                    .onPreferenceChange(SizePreferenceKey.self, perform: { value in
                        availableSize = value
                    })
                    .overlay(alignment: .top) {
                        if let image = context.snapshot, percent < 1 {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(snapshotPercent)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: conditionalCornerRadius / scaleRatio, style: cornerStyle))
                    .shadow(color: context.shadowColor ?? .clear, radius: context.shadowRadius, x: context.shadowOffset.x, y: context.shadowOffset.y)
                    .frame(
                        width: context.shouldScaleHorizontally ? proxy.size.width : zoomRect.size.width,
                        height: zoomRect.size.height / scaleRatio
                    )
                    .scaleEffect(x: scaleRatio, y: scaleRatio, anchor: .center)
                    .transformEffect(.init(translationX: context.anchor == nil ? (1 - percent) * proxy.size.width : 0, y: 0))
                    .position(
                        x: zoomRect.origin.x,
                        y: zoomRect.origin.y
                    )
                    .opacity(context.anchor == nil ? percent : 1)
            }
            .ignoresSafeArea(.container, edges: .all)
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }

    static var defaultValue: CGSize = .zero
}
