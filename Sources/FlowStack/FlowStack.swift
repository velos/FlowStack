//
//  FlowStack.swift
//  Flow
//
//  Created by Zac White on 2/14/23.
//

import SwiftUI

struct AnyDestination: Equatable {

    static func == (lhs: AnyDestination, rhs: AnyDestination) -> Bool {
        lhs.dataType == rhs.dataType
    }

    let dataType: Any.Type
    let destination: (Any) -> AnyView

    static func cast<T>(data: Any, to type: T.Type) -> T? {
        data as? T
    }
}

class DestinationLookup: ObservableObject {
    @Published var table: [String: AnyDestination] = [:]
}

struct FlowDestinationModifier<D: Hashable>: ViewModifier {
    @State var data: D.Type
    @State var destination: AnyDestination

    @EnvironmentObject var destinations: DestinationLookup

    func body(content: Content) -> some View {
        content
            // swiftlint:disable:next force_unwrapping
            .onAppear { destinations.table.merge([_mangledTypeName(data)!: destination], uniquingKeysWith: { _, rhs in rhs }) }
    }
}

extension View {
    func flowDestination<D, C>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View where D: Hashable, C: View {

        let destination = AnyDestination(dataType: data, destination: { param in
            guard let param = AnyDestination.cast(data: param, to: data) else {
                fatalError()
            }

            return AnyView(destination(param))
        })

        return modifier(FlowDestinationModifier(data: data, destination: destination))
    }
}

struct FlowStack<Root: View, Overlay: View>: View {

    @Binding private var path: FlowPath
    @State private var internalPath: FlowPath = FlowPath()

    private var overlayAlignment: Alignment
    private var root: () -> Root
    private var overlay: () -> Overlay

    private var usesInternalPath: Bool = false

    @State private var destinationLookup: DestinationLookup = .init()

    init(overlayAlignment: Alignment = .center, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
    }

    init(path: Binding<FlowPath>, overlayAlignment: Alignment = .center, @ViewBuilder root: @escaping () -> Root, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.root = root
        self.overlay = overlay
        self.overlayAlignment = overlayAlignment
        self._path = path
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

    var body: some View {
        ZStack {
            root()
                .environment(\.flowDepth, 0)

            ForEach(pathToUse.wrappedValue.elements, id: \.self) { element in
                if let destination = destination(for: element.value) {

                    skrim(for: element)

                    destination.destination(element.value)
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
        .animation(.interpolatingSpring(stiffness: 500, damping: 35), value: pathToUse.wrappedValue)
        .environment(\.flowPath, pathToUse)
        .environmentObject(destinationLookup)
    }
}

extension FlowStack where Overlay == EmptyView {
    init(@ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center

        self.usesInternalPath = true
        self._path = Binding(get: { FlowPath() }, set: { _ in })
    }

    init(path: Binding<FlowPath>, @ViewBuilder root: @escaping () -> Root) {
        self.root = root
        self.overlay = { EmptyView() }
        self.overlayAlignment = .center
        self._path = path
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
