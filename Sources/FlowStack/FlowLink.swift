//
//  FlowLink.swift
//
//  Created by Zac White on 2/14/23.
//

import SwiftUI

struct FlowLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.97 : 1, y: configuration.isPressed ? 0.97 : 1, anchor: .center)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FlowLinkButtonStyle {
    static var flowLink: FlowLinkButtonStyle {
        FlowLinkButtonStyle()
    }
}

struct PathContextKey: PreferenceKey {
    static var defaultValue: PathContext?

    static func reduce(value: inout PathContext?, nextValue: () -> PathContext?) {
        value = nextValue()
    }
}

struct AnimationAnchorKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

struct AnimationAnchorModifier: ViewModifier {

    @SwiftUI.Environment(\.opacityTransitionPercent) var percent

    func body(content: Content) -> some View {
        content
            .anchorPreference(key: AnimationAnchorKey.self, value: .bounds) { [$0] }
            .opacity(percent == 1 ? 1 : 0)
    }
}

public extension View {

    /// Configures the view as the origin for flow transition animations.
    /// If the transition uses a snapshot, the snapshot will only contain the contents of the view.
    func flowAnimationAnchor() -> some View {
        modifier(AnimationAnchorModifier())
    }
}

struct FlowDepthKey: EnvironmentKey {
    static var defaultValue: Int = 0
}

extension EnvironmentValues {
    var flowDepth: Int {
        get { self[FlowDepthKey.self] }
        set { self[FlowDepthKey.self] = newValue }
    }
}

struct GestureContainer: UIViewRepresentable {

    @Binding var isPressed: Bool
    var onTap: () -> Void

    class Coordinator {
        @Binding var isPressed: Bool
        var onTap: () -> Void

        init(isPressed: Binding<Bool>, onTap: @escaping () -> Void) {
            self._isPressed = isPressed
            self.onTap = onTap
        }

        @objc func onTouchUpInside() {
            isPressed = false
            onTap()
        }

        @objc func onEnter() {
            isPressed = true
        }

        @objc func onExit() {
            isPressed = false
        }
    }

    func makeUIView(context: Context) -> some UIView {
        let button = UIButton(type: .custom)
        button.addTarget(context.coordinator, action: #selector(Coordinator.onTouchUpInside), for: .touchUpInside)
        button.addTarget(context.coordinator, action: #selector(Coordinator.onEnter), for: [.touchDown, .touchDragInside])
        button.addTarget(context.coordinator, action: #selector(Coordinator.onExit), for: [.touchCancel, .touchDragOutside])
        return button
    }

    func updateUIView(_ uiView: UIViewType, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPressed: $isPressed, onTap: onTap)
    }
}

struct ButtonGestureModifier: ViewModifier {
    @State private var isPressed: Bool = false
    var action: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(GestureContainer(isPressed: $isPressed, onTap: action))
            .scaleEffect(x: isPressed ? 0.97 : 1, y: isPressed ? 0.97 : 1, anchor: .center)
            .animation(.easeOut(duration: 0.2), value: isPressed)
    }
}

extension View {
    func onButtonGesture(action: @escaping () -> Void) -> some View {
        modifier(ButtonGestureModifier(action: action))
    }
}

/// A view that controls a navigation presentation.
///
/// People click or tap a flow link to present a view inside a
/// `FlowStack`.
///
/// You control the visual appearance of the link by providing view content
/// in the link's `label` closure. The flow transition appearance can also be
/// customized using a `FlowLink.Configuration` object.
///
/// Flow navigation is performed based on a presented data value. To support this, use the
/// `View/flowDestination(for:destination:)` view modifier inside a flow stack
/// to associate a view with a kind of data, and then present a value of that
/// data type from a flow link. The following example FlowStack presents a corresponding
/// `ParkDetails(park:)` view any time a person taps a `FlowLink`.
///
///     FlowStack {
///         ScrollView {
///             LazyVStack {
///                 ForEach(parks) { park in
///                     FlowLink(value: park, configuration: .init(cornerRadius: cornerRadius)) {
///                         ParkRow(park: park, cornerRadius: cornerRadius)
///                     }
///                 }
///             }
///             .padding(.horizontal)
///         }
///         .flowDestination(for: Park.self) { park in
///             ParkDetails(park: park)
///         }
///     }
///
///**Control a flow link programmatically**
///
/// Separating the view from the data facilitates programmatic navigation
/// because you can manage navigation state by manually adding or removing presented data.
///
/// To navigate programmatically, introduce a state variable that tracks the `FlowPath`.
///
///     @State var flowPath = FlowPath()
///
/// Then pass a `Binding` to the state to the flow stack:
///
///     FlowStack(path: $flowPath) {
///         // ...
///     }
///
/// You can modify the flow path to change the contents of the stack. For example,
/// you can programmatically add a park to the flow path, and
/// navigation to a new park detail view using the following method:
///
///     func showJoshuaTree() {
///         flowPath.append(Park(name: "Joshua Tree"))
///     }
public struct FlowLink<Label>: View where Label: View {

    /// The zoom style applied to transitions to and from a destination view.
    public enum ZoomStyle {

        /// Scales the view contents in proportion to the view frame.
        ///
        /// Use this when you want a presented view's contents to maintain it's
        /// relative proportion and position during a transition. For example, allows
        /// views with multi-line text to maintain a consistent layout, avoiding line-break/word wrapping
        /// re-configuring during transitions.
        case scaleHorizontally

        /// Resizes the destination view frame during transitions
        /// while maintaining the original scale of the contents.
        ///
        /// As a result, the layout of the contents may adjust during
        /// transitions which may not be desirable for views containing
        /// multi-line text, as the placement of line-breaks/wrapping
        /// may change during transitions.
        case resize
    }

    /// A configuration object that defines behavior and appearance for a flow transition.
    public struct Configuration {

        /// Creates a configuration with the specified parameters.
        /// - Parameters:
        ///   - animateFromAnchor: Whether the destination view should transition from the associated flow link's bounds or flow link animation anchor.
        ///   - transitionFromSnapshot: Whether a snapshot image of the flow link label contents should be used during a transition.
        ///   - cornerRadius: The corner radius applied the transitioning destination view. This typically matches the corner style of the flow link contents or flow link animation anchor.
        ///   - cornerStyle: The corner radius applied the transitioning destination view. This typically matches the corner style of the flow link contents or flow link animation anchor.
        ///   - shadowRadius: The shadow radius applied to the transitioning destination view.
        ///   - shadowColor: The shadow color applied to the transitioning destination view.
        ///   - shadowOffset: The shadow offset applied to the transitioning destination view.
        ///   - zoomStyle: The zoom style applied to the transitioning destination view
        public init(animateFromAnchor: Bool = true, transitionFromSnapshot: Bool = true, cornerRadius: CGFloat = 0, cornerStyle: RoundedCornerStyle = .circular, shadowRadius: CGFloat = 0, shadowColor: Color? = nil, shadowOffset: CGPoint = .zero, zoomStyle: ZoomStyle = .scaleHorizontally) {
            self.animateFromAnchor = animateFromAnchor
            self.transitionFromSnapshot = transitionFromSnapshot
            self.cornerRadius = cornerRadius
            self.cornerStyle = cornerStyle
            self.shadowRadius = shadowRadius
            self.shadowColor = shadowColor
            self.shadowOffset = shadowOffset
            self.zoomStyle = zoomStyle
        }

        let animateFromAnchor: Bool
        let transitionFromSnapshot: Bool

        let cornerRadius: CGFloat
        let cornerStyle: RoundedCornerStyle

        let shadowRadius: CGFloat
        let shadowColor: Color?
        let shadowOffset: CGPoint

        let showsSkrim: Bool = true
        let zoomStyle: ZoomStyle
    }

    var label: () -> Label

    private var value: (any (Equatable & Hashable))?
    private var configuration: Configuration

    @SwiftUI.Environment(\.flowPath) private var path
    @SwiftUI.Environment(\.flowDepth) private var flowDepth

    @State private var overrideAnchor: Anchor<CGRect>?

    @State private var size: CGSize?
    @State private var overrideFrame: CGRect?
    @State private var context: PathContext?

    /// Creates a flow link that presents the view corresponding to a value.
    ///
    /// When someone activates the flow link that this initializer
    /// creates, SwiftUI looks for a nearby
    /// `View/flowDestination(for:destination:)` view modifier
    /// with a `data` input parameter that matches the type of this
    /// initializer's `value` input.
    ///
    /// If SwiftUI finds a matching modifier within the view hierarchy of an
    /// enclosing `FlowStack`, it adds the modifier's corresponding
    /// `destination` view onto the stack. Otherwise, the link doesn't do anything.
    ///
    /// - Parameters:
    ///   - value: An optional value to present.
    ///   - configuration: An object that allows for customization of the flow transition appearance. For example, matching the transition corner radius with that of the FlowLink Label contents.
    ///   - label: A label that describes the view that this link presents.
    public init<P>(value: P?, configuration: Configuration = .init(), @ViewBuilder label: @escaping () -> Label) where P: Hashable, P: Equatable {
        self.label = label
        self.value = value
        self.configuration = configuration
    }

    var isContainedInPath: Bool {
        guard let elements = path?.wrappedValue.elements, let value = value, elements.count > flowDepth else { return false }

        // treat -1 as special case to ignore the level on comparisons
        let depth = flowDepth == -1 ? nil : flowDepth

        return path?.wrappedValue.contains(value, atLevel: depth) ?? false
    }

    var hasSiblingElement: Bool {
        return path?.wrappedValue.elements.map(\.context?.linkDepth).contains(flowDepth) ?? false
    }

    @State private var snapshot: UIImage?

    @MainActor
    private func updateSnapshot() -> UIImage? {
        guard snapshot == nil else { return snapshot }

        guard let size = size else { return nil }

        let frame = CGRect(origin: .zero, size: size)

        let controller = UIHostingController(
            rootView: label()
                .environment(\.opacityTransitionPercent, 1)
                .ignoresSafeArea()
        )
        let view = controller.view

        guard let view = view else {
            return nil
        }

        view.bounds = CGRect(origin: .zero, size: size)
        view.backgroundColor = .clear

        controller.additionalSafeAreaInsets = UIEdgeInsets(top: -view.overlappingTopInset, left: 0, bottom: 0, right: 0)

        let renderer = UIGraphicsImageRenderer(size: frame.size)

        var image = renderer.image { _ in
            view.drawHierarchy(in: CGRect(x: 0, y: 0, width: size.width, height: size.height), afterScreenUpdates: true)
        }

        if let overrideFrame = overrideFrame,
           let croppedImage = crop(image, toRect: overrideFrame) {
            image = croppedImage
        }

        return image
    }

    /// Crops an image to the given frame.
    ///
    /// [Apple Docs - CGImage Cropping](https://developer.apple.com/documentation/coregraphics/cgimage/1454683-cropping)
    private func crop(_ inputImage: UIImage, toRect cropRect: CGRect) -> UIImage? {
        let scale = inputImage.scale

        // Scale cropRect relative to image scale
        let cropZone = CGRect(x: cropRect.origin.x * scale,
                              y: cropRect.origin.y * scale,
                              width: cropRect.size.width * scale,
                              height: cropRect.size.height * scale)


        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to:cropZone) else { return nil }

        // Return image to UIImage
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)
        return croppedImage
    }

    private var button: some View {
        label()
            .onButtonGesture {

                // check for sibling elements and return early if we already have a presented element at this depth
                guard !hasSiblingElement else {
                    return
                }

                Task {
                    if configuration.transitionFromSnapshot {
                        context?.snapshot = await updateSnapshot()
                    }

                    if let value = value {
                        path?.wrappedValue.append(value, context: context)
                    }
                }
            }
    }

    public var body: some View {
        Group {
            if isContainedInPath && configuration.animateFromAnchor {
                Color.clear
                    .frame(width: size?.width, height: size?.height)
            } else {
                if configuration.animateFromAnchor && overrideAnchor == nil {
                    button.transition(.invisible)
                } else if configuration.animateFromAnchor {
                    button.transition(.opacityPercent)
                } else {
                    button
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        if let anchor = context?.anchor {
                            size = proxy[anchor].size
                        }
                        if let overrideAnchor = overrideAnchor {
                            overrideFrame = proxy[overrideAnchor]
                        }
                    }
            }
        )
        .anchorPreference(key: PathContextKey.self, value: .bounds, transform: { anchor in
            return PathContext(
                anchor: configuration.animateFromAnchor ? anchor : nil,
                overrideAnchor: configuration.animateFromAnchor ? overrideAnchor : nil,
                snapshot: configuration.animateFromAnchor && configuration.transitionFromSnapshot ? snapshot : nil,
                linkDepth: flowDepth,
                cornerRadius: configuration.cornerRadius,
                cornerStyle: configuration.cornerStyle,
                shadowRadius: configuration.shadowRadius,
                shadowColor: configuration.shadowColor,
                shadowOffset: configuration.shadowOffset,
                shouldShowSkrim: configuration.showsSkrim,
                shouldScaleHorizontally: configuration.zoomStyle == .scaleHorizontally
            )
        })
        .onPreferenceChange(PathContextKey.self) { value in
            context = value
        }
        .onPreferenceChange(AnimationAnchorKey.self) { anchor in
            overrideAnchor = anchor.first
            context?.overrideAnchor = overrideAnchor
        }
    }
}
