//
//  FlowTransition.swift
//  Flow
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

public struct OpacityTransitionKey: EnvironmentKey {
    public static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
    var flowTransitionPercent: CGFloat {
        get { return self[FlowTransitionKey.self] }
        set { self[FlowTransitionKey.self] = newValue }
    }
}

public struct FlowTransitionKey: EnvironmentKey {
    public static let defaultValue: CGFloat = 0
}

public struct FlowDismissAction {

    var path: Binding<FlowPath>?
    var onDismiss: () -> Void = { }

    public func callAsFunction() {
        path?.wrappedValue.removeLast()
        onDismiss()
    }
}

public extension EnvironmentValues {
    var flowDismiss: FlowDismissAction {
        get { return self[FlowDismissActionKey.self] }
        set { self[FlowDismissActionKey.self] = newValue }
    }
}

public struct FlowDismissActionKey: EnvironmentKey {
    public static let defaultValue: FlowDismissAction = .init(path: .constant(.init()))
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

    static var invisible: AnyTransition {
        AnyTransition.modifier(
            active: InvisibleModifier(percent: 0),
            identity: InvisibleModifier(percent: 1)
        )
    }

    struct InvisibleModifier: AnimatableModifier {
        var percent: Double

        var animatableData: Double {
            get { percent }
            set { percent = newValue }
        }

        func body(content: Content) -> some View {
            content
                .opacity(percent == 1.0 ? 1 : 0)
        }
    }

    struct FlowPresentModifier: Animatable, ViewModifier {
        var percent: CGFloat
        var context: PathContext

        @State var panOffset: CGPoint = .zero
        @State var isEnded: Bool = false
        @State private var isDisabled: Bool = false
        @State var isDismissing: Bool = false

        private var snapshotPercent: CGFloat {
            max(0, 1 - percent / 0.2)
        }

        @SwiftUI.Environment(\.flowPath) var path

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
                width: rect.width + ((proxy.size.width - rect.width) * max(0, percent) * (1 - pullPercent)),
                height: rect.height + ((proxy.size.height - rect.height) * max(0, percent) * (1 - pullPercent))
            )

            return zoomRect
        }

        func body(content: Content) -> some View {
            GeometryReader { proxy in
                let zoomRect = zoomRect(with: proxy, anchor: context.overrideAnchor ?? context.anchor, percent: percent, pullOffset: panOffset)
                let scaleRatio = context.shouldScaleHorizontally ? zoomRect.size.width / proxy.size.width : 1.0
                let cornerRadius = context.cornerRadius + ((UIScreen.displayCornerRadius ?? 20) - context.cornerRadius) * percent
                let cornerStyle: RoundedCornerStyle = percent > 0.5 ? .continuous : context.cornerStyle

                content
                    .onInteractiveDismissGesture(threshold: 80, isEnabled: !isDisabled, isDismissing: isDismissing) {
                        path?.wrappedValue.removeLast()
                        isDismissing = true
                    } onPan: { offset in
                        isEnded = false
                        panOffset = offset
                    } onEnded: { _ in
                        isEnded = true
                        panOffset = .zero
                    }
                    .environment(\.flowDismiss, FlowDismissAction(path: path, onDismiss: { isDismissing = true }))
                    .onPreferenceChange(InteractiveDismissDisabledKey.self) { isDisabled in
                        self.isDisabled = isDisabled
                    }
                    .overlay {
                        if let image = context.snapshot, percent < 1 {
                            Image(uiImage: image)
                                .resizable()
                                .opacity(snapshotPercent)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius / scaleRatio, style: cornerStyle))
                    .shadow(color: context.shadowColor ?? .clear, radius: context.shadowRadius, x: context.shadowOffset.x, y: context.shadowOffset.y)
                    .frame(
                        width: context.shouldScaleHorizontally ? proxy.size.width : zoomRect.size.width,
                        height: zoomRect.size.height / scaleRatio
                    )
                    .scaleEffect(x: scaleRatio, y: scaleRatio, anchor: .center)
                    .rotation3DEffect(.degrees((1 - percent) * Double(20)), axis: (x: context.anchor == nil ? 1 : 0, y: 0, z: 0))
                    .position(
                        x: zoomRect.origin.x,
                        y: zoomRect.origin.y
                    )
                    .opacity(context.anchor == nil ? percent : 1)
            }
            .ignoresSafeArea(.container, edges: .all)
            .animation(.interpolatingSpring(stiffness: 500, damping: 35), value: isEnded)
            .environment(\.flowTransitionPercent, percent)
        }
    }
}
