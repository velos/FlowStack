//
//  FlowPath.swift
//  Flow
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

public struct PathContext: Equatable, Hashable {
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

public struct FlowPath: Equatable, Hashable {

    var elements: [FlowElement]

    public init() {
        elements = []
    }

    public var isEmpty: Bool {
        elements.isEmpty
    }

    var count: Int {
        elements.count
    }

    func contains<P>(_ element: P, atLevel level: Int?) -> Bool where P: Hashable {
        return elements.contains { $0 == FlowElement(value: element, context: $0.context, index: level ?? $0.index) }
    }

    public mutating func removeLast(_ count: Int = 1) {
        guard !isEmpty else { return }
        elements.removeLast(count)
    }

    public mutating func append<P>(_ newElement: P, context: PathContext? = nil) where P: Hashable {
        self.elements.append(.init(value: newElement, context: context, index: elements.count))
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
