//
//  FlowStack.swift
//
//  Created by Zac White on 2/14/23.
//

import Combine
import SwiftUI

struct AnyDestination: Equatable {

    static func == (lhs: AnyDestination, rhs: AnyDestination) -> Bool {
        lhs.dataType == rhs.dataType
    }

    let dataType: Any.Type
    let content: (Any) -> AnyView

    static func cast<T>(data: Any, to type: T.Type) -> T? {
        data as? T
    }
}

class DestinationLookup: ObservableObject {
    @Published var table: [String: AnyDestination] = [:]
}

class AccessibilityManager: ObservableObject {
    @Published var zIndex: Double = 0.0
    var skrimIndex: Double { zIndex - 0.1 }
    var behindSkrim: Double { zIndex - 0.2 }

    // Setup VoiceOver Observer
    @Published var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    init() {
        NotificationCenter.default
            .publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .map { _ in UIAccessibility.isVoiceOverRunning }
            .assign(to: &$isVoiceOverRunning)
    }

    func setIndex(_ input: Int) { self.zIndex = Double(input + 1)}

    func decrementIndex() { self.zIndex -= 1.0 }

    func calcSkrim() -> Double {
        if isVoiceOverRunning { return skrimIndex }
        return zIndex > 1.0 ? zIndex : skrimIndex
    }
}

struct AccessibilityModifier: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    var isHidden: (Double, Int) -> Bool = { d, i in d != Double(i + 1) }
    let element: Int

    func body(content: Content) -> some View {
        content
            .environment(\.flowDepth, element + 1)
            .zIndex(Double(accessibilityManager.zIndex))
            .accessibilityElement(children: .contain)
            .accessibilityHidden(isHidden(accessibilityManager.zIndex, element))
            .onAppear { accessibilityManager.setIndex(element) }
    }
}

struct FlowDestinationModifier<D: Hashable>: ViewModifier {
    @State var dataType: D.Type
    @State var destination: AnyDestination
    @EnvironmentObject var destinationLookup: DestinationLookup
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.flowDismiss) var flowDismiss

    func body(content: Content) -> some View {
        content
            .zIndex(accessibilityManager.isVoiceOverRunning ? accessibilityManager.zIndex : accessibilityManager.behindSkrim)
            // swiftlint:disable:next force_unwrapping
            .onAppear { destinationLookup.table.merge([_mangledTypeName(dataType)!: destination], uniquingKeysWith: { _, rhs in rhs }) }
    }
}

public extension View {

    /// Associates a destination view with a presented data type for use within
    /// a flow stack.
    ///
    /// Add this modifier to a view inside a `FlowStack` to
    /// specify the target view that the stack should display when presenting
    /// a certain type of data.
    ///
    /// Use a `FlowLink` to present the data. For example, you can present
    /// a `ParkDetail` view for each presentation of a `Park` instance:
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
    /// You can add more than one flow destination modifier to the stack
    /// if it needs to present more than one kind of data.
    ///
    /// Do not put a navigation destination modifier inside a "lazy" container,
    /// like ``List`` or ``LazyVStack``. These containers create child views
    /// only when needed to render on screen. Add the flow destination
    /// modifier outside these containers so that the flow stack can
    /// always see the destination.
    ///
    /// - Parameters:
    ///   - data: The type of data that this destination matches.
    ///   - destination: A view builder that defines a view to display
    ///     when the stack's flow navigation state contains a value of
    ///     type `data`. The closure takes one argument, which is the value
    ///     of the data to present.
    func flowDestination<D, C>(for type: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View where D: Hashable, C: View {
        let destination = AnyDestination(dataType: type, content: { param in
            guard let param = AnyDestination.cast(data: param, to: type) else {
                fatalError()
            }
            return AnyView (
                destination(param)
                    .accessibilityElement(children: .contain)
                    .accessibilityRespondsToUserInteraction(true)
            )
        })
        return modifier(FlowDestinationModifier(dataType: type, destination: destination))
    }
}

/// A view that displays a root view and enables you to present additional
/// views over the root view.
///
/// Use a flow stack to present a stack of views over a root view.
/// People can add views to the top of the stack by tapping a
/// `FlowLink`, and remove views using an interactive pull-to-dismiss gesture.
/// The stack always displays the most recently added view that hasn't been removed,
/// and doesn't allow the root view to be removed.
///
/// To create flow links, associate a view with a data type by adding a
/// `flowDestination(for:destination:)` modifier inside
/// the stack's view hierarchy. Then initialize a `FlowLink` that
/// presents an instance of the same kind of data. The following stack displays
/// a `ParkDetails` view for navigation links that present data of type `Park`:
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
/// In this example, the `ScrollView` (which contains a list of parks) acts as
/// the root view and is always present. Selecting a flow link from the list of parks
/// adds a `ParkDetails` view to the stack, so that it covers the list of parks.
/// Navigating back removes the detail view and reveals the list of parks again.
/// The system disables interactive dismiss navigation when the stack is empty
/// and the root view is visible.
///
/// **Manage flow navigation state**
///
/// By default, a flow stack manages state for any view contained, added or removed from the stack.
/// If you need direct access and control of the state, you can create a binding to a FlowPath
/// and initialize a flow stack with the flow path binding.
///
///     @State var flowPath = FlowPath()
///     ...
///
///     FlowStack(path: $flowPath) {
///         // ...
///     }
///
/// Like before, when someone taps or clicks the flow link for a
/// park, the stack displays the `ParkDetails` view using the associated park
/// data. As views are added and removed from the stack, the flow path is updated accordingly.
/// This allows for observation of the flow path if needed as well as the ability to
/// programmatically add and remove items and their associated views from the stack.
/// For example, programmatically presenting a park detail for "Joshua Tree" can be done by simply
/// appending a new park to the flow path.
///
///     func showJoshuaTree() {
///         flowPath.append(Park(name: "Joshua Tree"))
///     }
///
/// **Navigate to different view types**
///
/// To create a stack that can present more than one kind of view, you can add
/// multiple `flowDestination(for:destination:)` modifiers
/// inside the stack's view hierarchy, with each modifier presenting a
/// different data type. The stack matches flow links with flow
/// destinations based on their respective data types.
public struct FlowStack<Root: View, Overlay: View>: View {

    @Binding private var path: FlowPath
    @State private var internalPath: FlowPath = FlowPath()
    private var customSmoothAnimation: CustomSmoothAnimation

    private var overlayAlignment: Alignment
    private var root: () -> Root
    private var overlay: () -> Overlay

    private var usesInternalPath: Bool = false

    @State private var destinationLookup: DestinationLookup = .init()
    @StateObject var accessibilityManager: AccessibilityManager = .init()

    /// Creates a flow stack that manages its own navigation state.
    /// - Parameters:
    ///   - overlayAlignment: The alignment applied to the overlay.
    ///   - animation: The animation to use during flow transitions.
    ///   - root: The view to display when the stack is empty.
    ///   - overlay: The view to overlay on the FlowStack. This view is always visible in front of any view presented by the flow stack.
    public init(overlayAlignment: Alignment = .center, customSmoothAnimation: CustomSmoothAnimation?=nil, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment
        self.customSmoothAnimation = customSmoothAnimation ?? CustomSmoothAnimation.default

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
    }

    /// Creates a flow stack with heterogeneous navigation state that you can control.
    /// - Parameters:
    ///   - path: A Binding to the flow path for this stack.
    ///   - overlayAlignment: The alignment applied to the overlay.
    ///   - animation: The animation to use during flow transitions.
    ///   - root: The view to display when the stack is empty.
    ///   - overlay: The view to overlay on the FlowStack. This view is always visible in front of any view presented by the flow stack.
    public init(path: Binding<FlowPath>, overlayAlignment: Alignment = .center, customSmoothAnimation: CustomSmoothAnimation?=nil, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment
        self._path = path
        self.customSmoothAnimation = customSmoothAnimation ?? CustomSmoothAnimation.default
    }

    private func destination(for instance: any (Hashable & Equatable)) -> AnyDestination? {
        guard let typeName = _mangledTypeName(type(of: instance)), let destination = destinationLookup.table[typeName] else {
            return nil
        }

        return destination
    }

    @ViewBuilder
    private func skrim(for element: FlowElement) -> some View {
        if element == pathToUse.wrappedValue.elements.last, element.context?.shouldShowSkrim == true {
            Rectangle()
                .foregroundColor(Color.black.opacity(0.7))
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(accessibilityManager.calcSkrim())
                .id(element.hashValue)
                .onTapGesture {
                    flowDismissAction()
                }
        }
    }

    private var pathToUse: Binding<FlowPath> {
        usesInternalPath ? $internalPath : _path
    }

    private var flowDismissAction: FlowDismissAction {
        FlowDismissAction(
            onDismiss: {
                withTransaction(transaction) {
                    accessibilityManager.decrementIndex()
                    pathToUse.wrappedValue.removeLast()
                }
            })
    }

    private var transaction: Transaction {
        var transaction = Transaction(animation: customSmoothAnimation.animation)
        transaction.disablesAnimations = true
        return transaction
    }
    @Environment(\.flowDismiss) var flowDismiss
    public var body: some View {
        ZStack {
            root()
                .accessibilityElement(children: .contain)
                .accessibilityHidden(accessibilityManager.zIndex != 0)
                .environment(\.flowDepth, 0)

            ForEach(pathToUse.wrappedValue.elements, id: \.self) { element in
                if let destination = destination(for: element.value) {

                    skrim(for: element)

                    destination.content(element.value)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(element.hashValue)
                        .transition(.flowTransition(with: element.context ?? .init()))
                        .modifier(AccessibilityModifier(element: element.index))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .overlay(alignment: overlayAlignment) {
            overlay()
                .environment(\.flowDepth, -1)
        }
        .environment(\.flowPath, pathToUse)
        .environment(\.flowAnimationDuration, customSmoothAnimation.duration)
        .environment(\.flowTransaction, transaction)
        .environmentObject(destinationLookup)
        .environmentObject(accessibilityManager)
        .environment(\.flowDismiss, flowDismissAction)
    }
}

public extension FlowStack where Overlay == EmptyView {

    /// Creates a flow stack that manages its own navigation state.
    /// - Parameters:
    ///   - animation: The animation to use during flow transitions.
    ///   - root: The view to display when the stack is empty.
    init(customSmoothAnimation: CustomSmoothAnimation? = nil, @ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
        self.customSmoothAnimation = customSmoothAnimation ?? CustomSmoothAnimation.default
    }

    /// Creates a flow stack with heterogeneous navigation state that you can control.
    /// - Parameters:
    ///   - path: A Binding to the flow path for this stack.
    ///   - animation: The animation to use during flow transitions.
    ///   - root: The view to display when the stack is empty.
    init(path: Binding<FlowPath>, customSmoothAnimation: CustomSmoothAnimation? = nil, @ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center
        self._path = path
        self.customSmoothAnimation = customSmoothAnimation ??  CustomSmoothAnimation.default
    }
}

struct FlowTransactionKey: EnvironmentKey {
    static var defaultValue: Transaction = Transaction()
}

extension EnvironmentValues {
    var flowTransaction: Transaction {
        get { self[FlowTransactionKey.self] }
        set { self[FlowTransactionKey.self] = newValue }
    }
}

struct FlowPathAnimationKey: EnvironmentKey {
    static let defaultValue: Double = CustomSmoothAnimation.default.duration
}

public extension EnvironmentValues {
    var flowAnimationDuration: Double {
        get { self[FlowPathAnimationKey.self] }
        set { self[FlowPathAnimationKey.self] = newValue }
    }
}

@available(iOS 16.0, *)
struct FlowStack_Previews: PreviewProvider {
    static var previews: some View {
        FlowStack {
            List(0...10, id: \.self) { index in
                FlowLink(value: index) {
                    Text("Item \(index)")
                }
            }
            .flowDestination(for: Int.self) { index in
                Text("Destination \(index)")
            }
        }
    }
}

/// Object for passable parameters for smooth Animation
/// Had to be an animation type with a duration value so that it's trackable for flowStack
public struct CustomSmoothAnimation {
    var duration: Double
    var bounce: Double

    public init(duration: Double = 0.24, bounce: Double = 0.2) {
        self.duration = duration
        self.bounce = bounce
    }

    static let `default` = CustomSmoothAnimation(duration: 0.24, bounce: 0.2)

    var animation: Animation {
        .smooth(
            duration: duration,
            extraBounce: bounce
        )
    }
}

public extension Animation {

    /// The default animation to use during flow transitions.
    static var defaultFlow: Animation {
        CustomSmoothAnimation.default.animation
    }
}

struct FlowTransactionModifier: ViewModifier {
    @Environment(\.flowTransaction) var transaction
    @Environment(\.flowPath) var flowPath

    @State var initialPathCount: Int = 0
    @State var dismissCalled: Bool = false

    // (Workaround) to achieve onChange functionality for the path binding
    // in order to call the onDismiss handler the moment the presented view has been removed from the path.
    var path: FlowPath? {
        get {
            guard let path = flowPath else { return nil }

            if path.elements.count < initialPathCount, !dismissCalled {
                DispatchQueue.main.async {
                    dismissCalled = true
                    withTransaction(transaction) {
                        onDismiss?()
                    }
                }
            }

            return path.wrappedValue
        }
    }

    private var onPresent: (() -> Void)?
    private var onDismiss: (() -> Void)?

    init(onPresent: (() -> Void)?, onDismiss: (() -> Void)?) {
        self.onPresent = onPresent
        self.onDismiss = onDismiss
    }

    func body(content: Content) -> some View {
        content
            .onAppear(perform: {
                initialPathCount = path!.elements.count
                withTransaction(transaction) {
                    onPresent?()
                }
            })
            // (Workaround) onChange not passing value to `perform` closure.
            // Used to trigger the `path` getter where manual "onChange" is handled.
            .onChange(of: path, perform: { _ in })
    }
}

public extension View {

    /// Adds actions to perform with the flow animation of the view during transitions.
    ///
    /// FlowStack provides a default transition animation when
    /// presenting a destination view, but sometimes it's desirable
    /// to add additional animations to specific view elements within
    /// the presented view during the transition.
    ///
    /// For example, you may want a "close" button or other view elements
    /// to fade in during presentation and fade out when the view is dismissed.
    /// To do this, add a `withFlowAnimation(onPresent:onDismiss:)`
    /// modifier to your destination view and update the properties you want to
    /// animate respectively in the `onPresent` and `onDismiss` handlers.
    ///
    ///     // Destination view
    ///     @State var opacity: CGFloat = 0
    ///     ...
    ///
    ///     VStack {
    ///         image(url: park.imageUrl) // <- Example image loader using URL
    ///         Text(park.description)
    ///             .opacity(opacity) // <- Opacity for description text
    ///     }
    ///     .withFlowAnimation {
    ///         opacity = 1 // <- Animates with the flow transition presentation
    ///     } onDismiss: {
    ///         opacity = 0 // <- Animates with the flow transition dismissal
    ///     }
    func withFlowAnimation(onPresent: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(FlowTransactionModifier(onPresent: onPresent, onDismiss: onDismiss))
    }
}
