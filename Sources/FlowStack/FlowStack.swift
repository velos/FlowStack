//
//  FlowStack.swift
//
//  Created by Zac White on 2/14/23.
//

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

public struct FlowDestinationModifier<D: Hashable>: ViewModifier {
    @State var data: D.Type
    @State var destination: AnyDestination

    @EnvironmentObject var destinations: DestinationLookup

    public func body(content: Content) -> some View {
        content
            // swiftlint:disable:next force_unwrapping
            .onAppear { destinations.table.merge([_mangledTypeName(data)!: destination], uniquingKeysWith: { _, rhs in rhs }) }
    }
}

public extension View {
    func flowDestination<D, C>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View where D: Hashable, C: View {

        let destination = AnyDestination(dataType: data, content: { param in
            guard let param = AnyDestination.cast(data: param, to: data) else {
                fatalError()
            }

            return AnyView(destination(param))
        })

        return modifier(FlowDestinationModifier(data: data, destination: destination))
    }
}

public struct FlowStack<Root: View, Overlay: View>: View {

    @Binding private var path: FlowPath
    @State private var internalPath: FlowPath = FlowPath()
    private var animation: Animation

    private var overlayAlignment: Alignment
    private var root: () -> Root
    private var overlay: () -> Overlay

    private var usesInternalPath: Bool = false

    @State private var destinationLookup: DestinationLookup = .init()

    public init(overlayAlignment: Alignment = .center, animation: Animation = .defaultFlow, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment
        self.animation = animation

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
    }

    public init(path: Binding<FlowPath>, overlayAlignment: Alignment = .center, animation: Animation = .defaultFlow, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment
        self._path = path
        self.animation = animation
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
               .zIndex(Double(element.index + 1) - 0.1)
               .id(element.hashValue)
        }
    }

    private var pathToUse: Binding<FlowPath> {
        usesInternalPath ? $internalPath : _path
    }

    private var transaction: Transaction {
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = true
        return transaction
    }

    public var body: some View {
        ZStack {
            root()
                .environment(\.flowDepth, 0)

            ForEach(pathToUse.wrappedValue.elements, id: \.self) { element in
                if let destination = destination(for: element.value) {

                    skrim(for: element)

                    destination.content(element.value)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(element.hashValue)
                        .transition(.flowTransition(with: element.context ?? .init()))
                        .environment(\.flowDepth, element.index + 1)
                        .zIndex(Double(element.index) + 1)
                }
            }
        }
        .overlay(alignment: overlayAlignment) {
            overlay()
                .environment(\.flowDepth, -1)
        }
        .animation(animation, value: pathToUse.wrappedValue)
        .environment(\.flowPath, pathToUse.transaction(transaction))
        .environment(\.flowTransaction, transaction)
        .environmentObject(destinationLookup)
        .environment(\.flowDismiss, FlowDismissAction(
            onDismiss: {
                pathToUse.wrappedValue.removeLast()
            })
        )
    }
}

public extension FlowStack where Overlay == EmptyView {
    init(animation: Animation = .defaultFlow, @ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
        self.animation = animation
    }

    init(path: Binding<FlowPath>, animation: Animation = .defaultFlow, @ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center
        self._path = path
        self.animation = animation
    }
}

struct FlowTransactionKey: EnvironmentKey {
    static var defaultValue: Transaction = Transaction()
}

public extension EnvironmentValues {
    var flowTransaction: Transaction {
        get { self[FlowTransactionKey.self] }
        set { self[FlowTransactionKey.self] = newValue }
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

public extension Animation {
    static var defaultFlow: Animation { .interpolatingSpring(stiffness: 500, damping: 35) }
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
    func withFlowAnimation(onPresent: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(FlowTransactionModifier(onPresent: onPresent, onDismiss: onDismiss))
    }
}
