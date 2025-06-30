//
//  FlowPath.swift
//
//  Created by Zac White on 2/16/23.
//

import Foundation
import SwiftUI

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(minX)
        hasher.combine(minY)
        hasher.combine(width)
        hasher.combine(height)
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

struct PathContext: Equatable, Hashable {
    var anchor: Anchor<CGRect>?
    var overrideAnchor: Anchor<CGRect>?

    var snapshot: UIImage?
    var linkDepth: Int = 0

    var cornerRadius: CGFloat = 0
    var cornerStyle: RoundedCornerStyle = .circular

    var shadowRadius: CGFloat = 0
    var shadowColor: Color?
    var shadowOffset: CGPoint = .zero

    var shouldShowSkrim: Bool = true
    var shouldScaleHorizontally: Bool = true

    var transitionWithOpacity: Bool = false
}

struct FlowElement: Equatable, Hashable {
    var value: (any (Equatable & Hashable))
    var context: PathContext?
    var index: Int

    static func == (lhs: FlowElement, rhs: FlowElement) -> Bool {
        lhs.value.hashValue == rhs.value.hashValue &&
        _mangledTypeName(type(of: lhs.value)) == _mangledTypeName(type(of: rhs.value)) &&
        lhs.context == rhs.context &&
        lhs.index == rhs.index
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(_mangledTypeName(type(of: value)))
        hasher.combine(context)
        hasher.combine(index)
    }
}

/// A type-erased list of data representing the content of a flow stack.
public struct FlowPath: Equatable, Hashable {

    var elements: [FlowElement]

    public init() {
        elements = []
    }

    var isEmpty: Bool {
        elements.isEmpty
    }

    /// The number of elements in the flow path.
    public var count: Int {
        elements.count
    }

    func contains<P>(_ element: P, atLevel level: Int?) -> Bool where P: Hashable {
        return elements.contains { $0 == FlowElement(value: element, context: $0.context, index: level ?? $0.index) }
    }

    /// Removes the specified number of elements from the end of the flow path.
    /// - Parameter count: The number of elements to remove from the collection. Count must be greater than or equal to zero and must not exceed the number of elements in the flow path.
    public mutating func removeLast(_ count: Int = 1) {
        guard !isEmpty else { return }
        elements.removeLast(count)
    }

    mutating func append<P>(_ newElement: P, context: PathContext?) where P: Hashable {
        self.elements.append(.init(value: newElement, context: context, index: elements.count))
    }

    /// Adds a new element at the end of the flow path.
    /// - Parameters:
    ///   - newElement: The element to append to the flow path.
    public mutating func append<P>(_ newElement: P) where P: Hashable {
        self.append(newElement, context: nil)
    }
}

struct FlowPathKey: EnvironmentKey {
    static let defaultValue: Binding<FlowPath>? = .constant(FlowPath())
}

public extension EnvironmentValues {
    var flowPath: Binding<FlowPath>? {
        get { self[FlowPathKey.self] }
        set { self[FlowPathKey.self] = newValue }
    }
}
