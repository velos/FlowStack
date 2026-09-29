//
//  View+InteractiveDismiss.swift
//
//  Created by Zac White on 3/16/23.
//

import SwiftUI

extension UIView {
    var overlappingTopInset: CGFloat {
        if let currentWindow = self.window {
            let converted = convert(frame, to: currentWindow)
            let windowInsets = currentWindow.safeAreaInsets
            return min(max(0, converted.minY), windowInsets.top)
        } else if let foregroundWindow = UIWindowScene.firstForegroundScene?.windows.first(where: { $0.isKeyWindow }) {
            return foregroundWindow.safeAreaInsets.top
        } else {
            return 0
        }
    }
}

struct InteractiveDismissDisabledKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

public extension View {

    /// A modifier that allows for disabling or enabling interactive dismiss functionality for the view.
    /// - Parameter isDisabled: A `bool` that that determines if interactive dismiss functionality should be disabled for the view.
    func flowInteractiveDismissDisabled(_ isDisabled: Bool = true) -> some View {
        preference(key: InteractiveDismissDisabledKey.self, value: isDisabled)
    }
}

struct InteractiveDismissContainer<T: View>: UIViewControllerRepresentable {

    var threshold: Double

    var onPan: (CGPoint) -> Void
    var isEnabled: Bool
    var isDismissing: Bool

    var swipeUpToDismiss: Bool

    var onDismiss: () -> Void
    var onEnded: (Bool) -> Void

    let content: T

    func makeUIViewController(context: Context) -> InteractiveDismissViewController<T> {
        return InteractiveDismissViewController(rootView: content, coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: InteractiveDismissViewController<T>, context: Context) {
        context.coordinator.threshold = threshold
        context.coordinator.isEnabled = isEnabled
        context.coordinator.swipeUpToDismiss = swipeUpToDismiss
        context.coordinator.onPan = onPan
        context.coordinator.onDismiss = onDismiss
        context.coordinator.onEnded = onEnded
        context.coordinator.isDismissing = isDismissing
    }

    func makeCoordinator() -> InteractiveDismissCoordinator {
        InteractiveDismissCoordinator(threshold: threshold, isEnabled: isEnabled, onPan: onPan, isDismissing: isDismissing, swipeUpToDismiss: swipeUpToDismiss, onDismiss: onDismiss, onEnded: onEnded)
    }
}

class InteractiveDismissViewController<Content: View>: UIHostingController<Content> {

    private var coordinator: InteractiveDismissCoordinator
    private var frameObservation: NSKeyValueObservation?

    init(rootView: Content, coordinator: InteractiveDismissCoordinator) {
        self.coordinator = coordinator
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Where the view was in its window when the pull began.
    private var restingFrame: CGRect?

    /// Gives up on a view that was let go but never got back to where it rested.
    private var settleTimeout: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        coordinator.onUpdatingChanged = { [weak self] in
            self?.updateSafeAreaCompensation()
        }

        frameObservation = view.observe(\.frame) { [weak self] _, _ in
            self?.updateSafeAreaCompensation()
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSafeAreaCompensation()
    }

    /// Keeps the content's safe area as it was at rest while a pull has the view out of place.
    ///
    /// A view loses safe area inset on an edge as it moves in from that edge of the screen, so
    /// its content would reflow as it is pulled around. That is any edge with an inset: the
    /// top in portrait, and either side in landscape, where an edge swipe drags the view
    /// clean away from the inset it started against.
    ///
    /// A pull that is let go leaves the view out of place until it has sprung back, so that
    /// is how long this lasts, rather than only for as long as the finger is down.
    private func updateSafeAreaCompensation() {
        guard let window = view.window else {
            endSafeAreaCompensation()
            return
        }

        let frame = view.convert(view.bounds, to: window)
        noteNavigationBarPlacement(frame: frame)

        if coordinator.isUpdating {
            settleTimeout?.cancel()
            settleTimeout = nil
            restingFrame = restingFrame ?? frame
        }

        guard let restingFrame = restingFrame else {
            endSafeAreaCompensation()
            return
        }

        if !coordinator.isUpdating {
            if frame.isApproximatelyEqual(to: restingFrame) {
                endSafeAreaCompensation()
                return
            }
            if settleTimeout == nil {
                // The layout can change underneath a view that is settling, by rotating,
                // say, and then it never gets back to where it was.
                let timeout = DispatchWorkItem { [weak self] in self?.endSafeAreaCompensation() }
                settleTimeout = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.settleTimeout, execute: timeout)
            }
        }

        let compensation = Self.safeAreaCompensation(
            frame: frame,
            restingFrame: restingFrame,
            windowBounds: window.bounds,
            windowInsets: window.safeAreaInsets
        )
        if !compensation.isApproximatelyEqual(to: additionalSafeAreaInsets) {
            additionalSafeAreaInsets = compensation
        }

        holdNavigationStacks()
    }

    private func endSafeAreaCompensation() {
        settleTimeout?.cancel()
        settleTimeout = nil
        restingFrame = nil

        if additionalSafeAreaInsets != .zero {
            additionalSafeAreaInsets = .zero
        }
        releaseNavigationStacks()
    }

    // MARK: Navigation bar placement

    /// Whether the view has overhung the top of the screen since its navigation bars were
    /// last placed at rest.
    private var overhungTop = false
    private var barPlacementCheck: DispatchWorkItem?

    /// Has a navigation stack inside the view place its bar again once the view has come to
    /// rest after overhanging the top of the screen.
    ///
    /// Before iOS 26, a navigation controller places its bar by how far its view sits under the
    /// status bar, but only works that out now and then: when the view first reaches the status
    /// bar, and when it starts or stops overhanging the top of the screen. A presentation's
    /// spring overshoots, so the view overhangs briefly on arriving, and when it settles back
    /// the bar is placed from a stale measurement taken partway through the presentation, well
    /// above where it belongs. Hiding and showing the bar, in one turn of the run loop so that
    /// nothing is drawn without it, has it measured again.
    private func noteNavigationBarPlacement(frame: CGRect) {
        if #available(iOS 26.0, *) { return }

        if frame.minY < -Constants.tolerance {
            overhungTop = true
        }
        guard overhungTop, restingFrame == nil else { return }

        barPlacementCheck?.cancel()
        let check = DispatchWorkItem { [weak self] in self?.placeNavigationBarsAtRest() }
        barPlacementCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.barPlacementDelay, execute: check)
    }

    private func placeNavigationBarsAtRest() {
        barPlacementCheck = nil
        guard overhungTop, restingFrame == nil, let window = view.window,
              view.convert(view.bounds, to: window).minY >= -Constants.tolerance else { return }
        overhungTop = false

        for navigationController in navigationControllers(in: self) {
            guard !navigationController.isNavigationBarHidden,
                  !Self.containsFirstResponder(navigationController.view) else { continue }
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }

    private static func containsFirstResponder(_ view: UIView) -> Bool {
        view.isFirstResponder || view.subviews.contains(where: containsFirstResponder)
    }

    // MARK: Navigation stacks

    /// A navigation stack inside the content, and where its bar and content sat at rest.
    private struct HeldNavigationStack {
        weak var navigationController: UINavigationController?
        /// Where the bar sat, on systems that move it during a pull.
        var barMinY: CGFloat?
        var contentInsets: UIEdgeInsets
        /// The edges of the content's safe area that are held. The top always is, for the bar.
        /// Another edge is only held while nothing but the navigation controller contributes
        /// to it: an edge with a keyboard against it, say, is worked out from the keyboard's
        /// overlap by UIKit, which takes anything added to it into account and never settles.
        var heldEdges: UIRectEdge
        /// What has been added to the top view controller's safe area to hold its insets.
        var addedInsets: UIEdgeInsets = .zero
        var observations: [NSKeyValueObservation] = []
        var floatingItems: [HeldFloatingItem] = []
    }

    /// An item floating over a navigation stack's content, and where it sat at rest in this view.
    ///
    /// From iOS 26 a navigation stack can float its items in a pocket beside the screen's
    /// system UI, as a folded iPhone Duo does beside its camera column. The pocket is placed
    /// on screen, so as a pull moves the view the items slide about inside it, staying put on
    /// screen until the view's edge stops them. The pocket's layout works from where its
    /// container is on screen, so the container can't be moved back without the layout
    /// following it around; the item itself can, since the layout only places it.
    private struct HeldFloatingItem {
        /// The view that is moved back: the item's control, with the compact views around it
        /// that its layout places as one.
        weak var item: UIView?
        weak var control: UIView?
        /// Where the control sat at rest, in this view.
        var center: CGPoint
        var observations: [NSKeyValueObservation] = []
    }

    private var heldNavigationStacks: [HeldNavigationStack]?
    /// Setting a safe area reports it changed, synchronously, which mustn't hold again.
    private var isHoldingNavigationStacks = false

    /// Holds the content of any navigation stack inside this view laid out as it was at rest.
    ///
    /// A navigation controller works its content's safe area out for itself, from where the
    /// content sits on screen, so holding this view's safe area doesn't reach it. Its content
    /// gains inset on an edge as the content overhangs that edge of the screen, which an edge
    /// swipe does to the trailing edge, where iPhone Duo's camera and status items are. And
    /// before iOS 26 the bar is placed by how far the content sits under the status bar: as
    /// a pull moves the view down, the bar slides up inside it and the top inset shrinks.
    private func holdNavigationStacks() {
        guard !isHoldingNavigationStacks else { return }
        isHoldingNavigationStacks = true
        defer { isHoldingNavigationStacks = false }

        if heldNavigationStacks == nil {
            heldNavigationStacks = navigationControllers(in: self).compactMap { navigationController in
                let bar = navigationController.navigationBar
                guard bar.transform.isIdentity, let content = navigationController.topViewController else { return nil }

                let contentInsets = content.view.safeAreaInsets
                let ownInsets = navigationController.view.safeAreaInsets
                var heldEdges: UIRectEdge = .top
                if abs(contentInsets.left - ownInsets.left) < Constants.tolerance { heldEdges.insert(.left) }
                if abs(contentInsets.right - ownInsets.right) < Constants.tolerance { heldEdges.insert(.right) }
                if abs(contentInsets.bottom - ownInsets.bottom) < Constants.tolerance { heldEdges.insert(.bottom) }

                var held = HeldNavigationStack(navigationController: navigationController, contentInsets: contentInsets, heldEdges: heldEdges)
                if #unavailable(iOS 26.0), !navigationController.isNavigationBarHidden {
                    held.barMinY = bar.frame.minY
                }
                held.observations.append(bar.layer.observe(\.position) { [weak self] _, _ in
                    self?.holdNavigationStacks()
                })
                held.observations.append(content.view.observe(\.safeAreaInsets) { [weak self] _, _ in
                    self?.holdNavigationStacks()
                })
                held.floatingItems = floatingItems(in: navigationController)
                return held
            }
        }

        for index in (heldNavigationStacks ?? []).indices {
            guard let held = heldNavigationStacks?[index], let navigationController = held.navigationController else { continue }

            // Moved by a transform, which the navigation controller's own layout leaves be.
            let bar = navigationController.navigationBar
            if let barMinY = held.barMinY {
                let offset = barMinY - (bar.center.y - bar.bounds.height / 2)
                if abs(bar.transform.ty - offset) > Constants.tolerance {
                    bar.transform = CGAffineTransform(translationX: 0, y: offset)
                }
            }

            for floating in held.floatingItems {
                guard let item = floating.item, let control = floating.control, let superview = control.superview else { continue }
                // Where the layout has put the control, in this view, were the item not moved back.
                let placed = superview.convert(control.center, to: view)
                let translation = CGPoint(
                    x: floating.center.x - placed.x + item.transform.tx,
                    y: floating.center.y - placed.y + item.transform.ty
                )
                if abs(translation.x - item.transform.tx) > Constants.tolerance || abs(translation.y - item.transform.ty) > Constants.tolerance {
                    item.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
                }
            }

            guard let content = navigationController.topViewController else { continue }
            var added = held.addedInsets + held.contentInsets - content.view.safeAreaInsets
            if !held.heldEdges.contains(.left) { added.left = 0 }
            if !held.heldEdges.contains(.right) { added.right = 0 }
            if !held.heldEdges.contains(.bottom) { added.bottom = 0 }
            if !added.isApproximatelyEqual(to: held.addedInsets, tolerance: Constants.tolerance) {
                heldNavigationStacks?[index].addedInsets = added
                content.additionalSafeAreaInsets = content.additionalSafeAreaInsets + added - held.addedInsets
            }
        }
    }

    private func releaseNavigationStacks() {
        for held in heldNavigationStacks ?? [] {
            held.observations.forEach { $0.invalidate() }
            guard let navigationController = held.navigationController else { continue }

            navigationController.navigationBar.transform = .identity
            for floating in held.floatingItems {
                floating.observations.forEach { $0.invalidate() }
                floating.item?.transform = .identity
            }
            if held.addedInsets != .zero, let content = navigationController.topViewController {
                content.additionalSafeAreaInsets = content.additionalSafeAreaInsets - held.addedInsets
            }
        }
        heldNavigationStacks = nil
    }

    /// The items floating over a navigation stack's content: each control in whatever the
    /// navigation controller's view holds besides its bar and its content, taken with the
    /// compact views around it that its layout places as one.
    private func floatingItems(in navigationController: UINavigationController) -> [HeldFloatingItem] {
        guard #available(iOS 26.0, *) else { return [] }
        let content = navigationController.topViewController?.view

        return navigationController.view.subviews.flatMap { container -> [HeldFloatingItem] in
            guard container !== navigationController.navigationBar, content?.isDescendant(of: container) != true else { return [] }

            return controls(in: container).compactMap { control in
                var item: UIView = control
                while let superview = item.superview, superview !== container,
                      superview.bounds.width <= Constants.maxFloatingItemSize, superview.bounds.height <= Constants.maxFloatingItemSize {
                    item = superview
                }
                guard item.transform.isIdentity, let superview = control.superview else { return nil }

                var held = HeldFloatingItem(item: item, control: control, center: superview.convert(control.center, to: view))
                var ancestor: UIView? = item
                while let current = ancestor, current !== container {
                    held.observations.append(current.layer.observe(\.position) { [weak self] _, _ in
                        self?.holdNavigationStacks()
                    })
                    ancestor = current.superview
                }
                return held
            }
        }
    }

    private func controls(in view: UIView) -> [UIView] {
        view.subviews.flatMap { $0 is UIControl ? [$0] : controls(in: $0) }
    }

    private func navigationControllers(in viewController: UIViewController) -> [UINavigationController] {
        viewController.children.flatMap { child -> [UINavigationController] in
            if let navigationController = child as? UINavigationController {
                return [navigationController]
            }
            return navigationControllers(in: child)
        }
    }

    private enum Constants {
        static var tolerance: CGFloat { 0.1 }
        static var settleTimeout: TimeInterval { 1 }
        /// Long enough for a settling view to have stopped moving, short enough not to be seen.
        static var barPlacementDelay: TimeInterval { 0.05 }
        /// Larger than any floating item; smaller than the views that lay them out.
        static var maxFloatingItemSize: CGFloat { 120 }
    }

    /// The safe area inset a view has lost on each edge since it was at rest.
    ///
    /// On each edge a view has the window's inset less however far it sits in from that edge,
    /// and never less than none. A view that overhangs an edge gains nothing for it.
    static func safeAreaCompensation(frame: CGRect, restingFrame: CGRect, windowBounds: CGRect, windowInsets: UIEdgeInsets) -> UIEdgeInsets {
        func lost(_ distanceFromEdge: CGFloat, of inset: CGFloat) -> CGFloat {
            min(max(0, distanceFromEdge), inset)
        }

        func compensation(_ distance: (CGRect) -> CGFloat, of inset: CGFloat) -> CGFloat {
            lost(distance(frame), of: inset) - lost(distance(restingFrame), of: inset)
        }

        return UIEdgeInsets(
            top: compensation({ $0.minY - windowBounds.minY }, of: windowInsets.top),
            left: compensation({ $0.minX - windowBounds.minX }, of: windowInsets.left),
            bottom: compensation({ windowBounds.maxY - $0.maxY }, of: windowInsets.bottom),
            right: compensation({ windowBounds.maxX - $0.maxX }, of: windowInsets.right)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        findScrollViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // SwiftUI content can introduce or replace its scroll view after the
        // hosting controller first appears (for example, after async loading).
        findScrollViews()
    }

    func findScrollViews() {

        guard let scrollView = findScrollViews(in: [view]) else {
            coordinator.scrollView = nil
            coordinator.view = view
            return
        }

        coordinator.scrollView = scrollView
        coordinator.view = scrollView.superview
    }

    private func findScrollViews(in subviews: [UIView]) -> UIScrollView? {

        let scrollViews = subviews.compactMap({ $0 as? UIScrollView })

        guard let subview = scrollViews.first(where: { $0.frame.width >= view.frame.width || $0.frame.height >= view.frame.height }) else {
            return subviews.compactMap { findScrollViews(in: $0.subviews) }.first
        }

        return subview
    }
}

class InteractiveDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    var threshold: Double

    var onPan: (CGPoint) -> Void
    var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            panGestureRecognizer?.isEnabled = isEnabled
            edgeGestureRecognizer?.isEnabled = isEnabled

            // The content can disable dismissal after a pull has already begun.
            // Return it to rest now, without waiting for the finger to lift.
            guard !isEnabled, isUpdating, !isDismissing else { return }
            isUpdating = false
            isPastThreshold = false
            scrollView?.isScrollEnabled = true
            onEnded(false)
        }
    }
    var isDismissing: Bool {
        didSet {
            guard isDismissing else { return }
            handleDismiss()
        }
    }

    var swipeUpToDismiss: Bool

    var onDismiss: () -> Void
    var onEnded: (Bool) -> Void

    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var edgeGestureRecognizer: UIScreenEdgePanGestureRecognizer!

    /// Whether a pull is under way, or has ended in a dismissal that is still animating.
    var isUpdating: Bool = false {
        didSet {
            if isUpdating != oldValue {
                onUpdatingChanged?()
            }
        }
    }

    var onUpdatingChanged: (() -> Void)?

    private var isPastThreshold: Bool = false
    private var impactGenerator: UIImpactFeedbackGenerator

    fileprivate var view: UIView? {
        didSet {
            guard oldValue !== view else { return }

            panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
            edgeGestureRecognizer.view?.removeGestureRecognizer(edgeGestureRecognizer)

            view?.addGestureRecognizer(panGestureRecognizer)
            view?.addGestureRecognizer(edgeGestureRecognizer)
            view?.clipsToBounds = true
        }
    }

    fileprivate var scrollView: UIScrollView?

    init(threshold: Double, isEnabled: Bool, onPan: @escaping (CGPoint) -> Void, isDismissing: Bool, swipeUpToDismiss: Bool, onDismiss: @escaping () -> Void, onEnded: @escaping (Bool) -> Void) {
        self.threshold = threshold

        self.onPan = onPan
        self.isEnabled = isEnabled
        self.isDismissing = isDismissing
        self.swipeUpToDismiss = swipeUpToDismiss
        self.onDismiss = onDismiss
        self.onEnded = onEnded

        self.impactGenerator = UIImpactFeedbackGenerator(style: .medium)

        super.init()

        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureUpdated(recognizer:)))
        self.panGestureRecognizer.delegate = self

        self.edgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeGestureUpdated(recognizer:)))
        self.edgeGestureRecognizer.edges = [.left]
        self.edgeGestureRecognizer.delegate = self

        self.panGestureRecognizer.require(toFail: self.edgeGestureRecognizer)
        self.panGestureRecognizer.isEnabled = isEnabled
        self.edgeGestureRecognizer.isEnabled = isEnabled
    }

    @objc
    private func edgeGestureUpdated(recognizer: UIScreenEdgePanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let offset = recognizer.translation(in: view)
        update(offset: offset, isEdge: true, state: recognizer.state)
    }

    @objc
    private func panGestureUpdated(recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let offset = recognizer.translation(in: view)

        update(offset: offset, isEdge: false, state: recognizer.state)
    }

    private func update(offset: CGPoint, isEdge: Bool, state: UIGestureRecognizer.State) {
        guard isEnabled, !isDismissing else { return }
        isUpdating = true
        onPan(offset)

        let isPastThreshold = offset.y > threshold || (offset.x > threshold && isEdge) || (-offset.y > threshold * 2 && swipeUpToDismiss)
        if isPastThreshold != self.isPastThreshold && isPastThreshold, isEnabled {
            impactGenerator.impactOccurred()
        }

        self.isPastThreshold = isPastThreshold

        // The system can take a gesture away, for an incoming call, say. That has to end the
        // pull as well, or the view is left wherever it had been pulled to. It shouldn't
        // dismiss, though, since it wasn't the person's doing.
        let hasEnded = state == .ended || state == .cancelled || state == .failed
        let shouldDismiss = isPastThreshold && state == .ended

        if hasEnded {
            if shouldDismiss {
                onDismiss()
                self.isPastThreshold = false
            } else {
                isUpdating = false
            }
            onEnded(shouldDismiss)
            guard let scrollView = scrollView else { return }
            scrollView.isScrollEnabled = true
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isEnabled, !isDismissing else { return false }
        guard let scrollView = scrollView else { return true }
        scrollView.isScrollEnabled = true
        guard gestureRecognizer == panGestureRecognizer else { return true }

        if panGestureRecognizer.translation(in: scrollView).y > 0 {
            return scrollView.contentOffset.y - 5 <= -scrollView.contentInset.top
        } else {
            let belowBounds = scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height + 20 && swipeUpToDismiss
            scrollView.isScrollEnabled = !belowBounds
            return belowBounds
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isEnabled, !isDismissing else { return false }
        guard gestureRecognizer == panGestureRecognizer || gestureRecognizer == edgeGestureRecognizer, let scrollView = scrollView else {
            return true
        }
        scrollView.isScrollEnabled = true

        if gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == edgeGestureRecognizer {
            return false
        }

        let hasEdgeTranslation = edgeGestureRecognizer.translation(in: view).x > 0

        guard otherGestureRecognizer.view?.isKind(of: UIScrollView.self) ?? false else { return false }
        guard scrollView.contentOffset.y - 5 <= -scrollView.contentInset.top || hasEdgeTranslation else { return true }

        let shouldDisableScroll = (panGestureRecognizer.translation(in: scrollView).y > 0 || hasEdgeTranslation)

        if shouldDisableScroll {
            otherGestureRecognizer.isEnabled = false
            otherGestureRecognizer.isEnabled = true
        }
        return true
    }

    func handleDismiss() {
        view?.isUserInteractionEnabled = false
        if let scrollView = scrollView {
            UIView.animate(withDuration: 0.2) {
                scrollView.contentOffset = .init(x: scrollView.contentOffset.x, y: -scrollView.contentInset.top)
            }
        }
    }
}

extension View {
    func onInteractiveDismissGesture(threshold: Double = 50, isEnabled: Bool = true, isDismissing: Bool = false, swipeUpToDismiss: Bool, onDismiss: @escaping () -> Void, onPan: @escaping (CGPoint) -> Void = { _ in }, onEnded: @escaping (Bool) -> Void = { _ in }) -> some View {
        InteractiveDismissContainer(threshold: threshold, onPan: onPan, isEnabled: isEnabled, isDismissing: isDismissing, swipeUpToDismiss: swipeUpToDismiss, onDismiss: onDismiss, onEnded: onEnded, content: self)
    }
}

extension UIEdgeInsets {
    static func + (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: lhs.top + rhs.top, left: lhs.left + rhs.left, bottom: lhs.bottom + rhs.bottom, right: lhs.right + rhs.right)
    }

    static func - (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: lhs.top - rhs.top, left: lhs.left - rhs.left, bottom: lhs.bottom - rhs.bottom, right: lhs.right - rhs.right)
    }

    /// Whether the insets differ by less than could be seen. Setting a view controller's
    /// additional safe area insets changes its safe area, which is one of the things that
    /// prompts them to be worked out, so this is what lets that settle.
    func isApproximatelyEqual(to other: UIEdgeInsets, tolerance: CGFloat = 0.1) -> Bool {
        abs(top - other.top) < tolerance && abs(left - other.left) < tolerance &&
        abs(bottom - other.bottom) < tolerance && abs(right - other.right) < tolerance
    }
}

extension CGRect {
    /// Whether the rectangles differ by less than could be seen.
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.1) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance &&
        abs(width - other.width) < tolerance && abs(height - other.height) < tolerance
    }
}
