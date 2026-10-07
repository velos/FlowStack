//
//  FlowPath.swift
//
//  Created by Zac White on 2/16/23.
//

import Foundation
import SwiftUI

struct PathContext: Equatable, Hashable {
    var anchor: Anchor<CGRect>?
    var overrideAnchor: Anchor<CGRect>?

    var snapshot: UIImage?
    var snapshotDict: [ColorScheme: UIImage] = [:]
    var linkDepth: Int = 0

    var cornerRadius: CGFloat = 0
    var cornerStyle: RoundedCornerStyle = .circular

    var shadowRadius: CGFloat = 0
    var shadowColor: Color?
    var shadowOffset: CGPoint = .zero

    var shouldShowScrim: Bool = true
    var shouldScaleHorizontally: Bool = true

    var swipeUpToDismiss: Bool = false

    var presentationStyle: FlowPresentationStyle = .automatic

    // Hashes a subset of the equated properties (anchors and shadowOffset are
    // excluded because Anchor<CGRect> and CGPoint are not Hashable), which
    // still satisfies the Hashable contract: equal values hash equally.
    func hash(into hasher: inout Hasher) {
        hasher.combine(snapshot)
        hasher.combine(linkDepth)
        hasher.combine(cornerRadius)
        hasher.combine(shadowRadius)
        hasher.combine(shadowColor)
        hasher.combine(shouldShowScrim)
        hasher.combine(shouldScaleHorizontally)
        hasher.combine(swipeUpToDismiss)
        hasher.combine(presentationStyle)
    }
}

struct FlowElement: Equatable, Hashable {
    var value: (any (Equatable & Hashable))
    var context: PathContext?
    /// The flow link the value was presented from, where that is known. A value appended to
    /// the flow path directly comes from whichever link presents it.
    var source: FlowLinkSource?
    var index: Int

    static func == (lhs: FlowElement, rhs: FlowElement) -> Bool {
        AnyHashable(lhs.value) == AnyHashable(rhs.value) &&
        lhs.index == rhs.index
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(value))
        hasher.combine(index)
    }
}

/// A type-erased list of data representing the content of a flow stack.
public struct FlowPath: Equatable, Hashable {

    var elements: [FlowElement]

    /// Creates a new, empty flow path.
    public init() {
        elements = []
    }

    /// A Boolean that indicates whether the flow path is empty.
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// The number of elements in the flow path.
    public var count: Int {
        elements.count
    }

    func contains<P>(_ element: P, atLevel level: Int?) -> Bool where P: Hashable {
        self.element(presenting: element, atLevel: level) != nil
    }

    func element<P>(presenting value: P, atLevel level: Int?) -> FlowElement? where P: Hashable {
        elements.first { $0 == FlowElement(value: value, context: $0.context, index: level ?? $0.index) }
    }

    /// Removes the specified number of elements from the end of the flow path.
    /// - Parameter count: The number of elements to remove from the flow path. If `count` exceeds the
    ///   number of elements in the flow path, all elements are removed.
    public mutating func removeLast(_ count: Int = 1) {
        elements.removeLast(Swift.min(Swift.max(count, 0), elements.count))
    }

    /// Removes all elements from the flow path, returning to the root view.
    public mutating func removeAll() {
        elements.removeAll()
    }

    mutating func append<P>(_ newElement: P, context: PathContext?, source: FlowLinkSource? = nil) where P: Hashable {
        self.elements.append(.init(value: newElement, context: context, source: source, index: elements.count))
    }

    /// Adds a new element at the end of the flow path.
    /// - Parameters:
    ///   - newElement: The element to append to the flow path.
    public mutating func append<P>(_ newElement: P) where P: Hashable {
        self.append(newElement, context: nil)
    }

    /// Adds a new element at the end of the flow path, presented from a particular flow link.
    ///
    /// Use this when more than one flow link presents `newElement`, to choose which of them
    /// the destination zooms out of and back into.
    /// - Parameters:
    ///   - newElement: The element to append to the flow path.
    ///   - linkID: The identifier given to the flow link with `flowLinkID(_:)`.
    public mutating func append<P, ID>(_ newElement: P, linkID: ID) where P: Hashable, ID: Hashable {
        self.append(newElement, context: nil, source: FlowLinkSource(link: .explicit(AnyHashable(linkID))))
    }

    /// Does nothing. Flow links keep a snapshot for each color scheme, and the right one is
    /// chosen as a transition renders, so there is nothing to update when the scheme changes.
    @available(*, deprecated, message: "This no longer does anything and can be removed. The snapshot for the current color scheme is chosen automatically.")
    public mutating func updateSnapshots(from colorScheme: ColorScheme) { }
}

struct FlowPathKey: EnvironmentKey {
    static let defaultValue: Binding<FlowPath>? = .constant(FlowPath())
}

public extension EnvironmentValues {
    /// A binding to the path of the enclosing flow stack.
    ///
    /// Inside a flow stack, this is the stack's ``FlowPath``, whether the stack manages it
    /// or it was passed in. Outside one, it's a constant, empty path.
    var flowPath: Binding<FlowPath>? {
        get { self[FlowPathKey.self] }
        set { self[FlowPathKey.self] = newValue }
    }
}
