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
    var onDismiss: () -> Void
    var onEnded: (Bool) -> Void

    let content: T

    func makeUIViewController(context: Context) -> InteractiveDismissViewController<T> {
        return InteractiveDismissViewController(rootView: content, coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: InteractiveDismissViewController<T>, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isDismissing = isDismissing
    }

    func makeCoordinator() -> InteractiveDismissCoordinator {
        InteractiveDismissCoordinator(threshold: threshold, onPan: onPan, isEnabled: isEnabled, isDismissing: isDismissing, onDismiss: onDismiss, onEnded: onEnded)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        frameObservation = view.observe(\.frame) { [weak self] theView, _ in
            guard let self = self else { return }
            self.additionalSafeAreaInsets = UIEdgeInsets(
                top: coordinator.isUpdating ? theView.overlappingTopInset : 0,
                left: 0,
                bottom: 0,
                right: 0
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        findScrollViews()
    }

    func findScrollViews() {

        guard let scrollView = findScrollViews(in: [view]) else {
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

class InteractiveDismissCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    var threshold: Double

    var onPan: (CGPoint) -> Void
    var isEnabled: Bool {
        didSet {
            panGestureRecognizer.isEnabled = isEnabled
            edgeGestureRecognizer.isEnabled = isEnabled
        }
    }
    var isDismissing: Bool {
        didSet {
            guard isDismissing else { return }
            handleDismiss()
        }
    }
    var onDismiss: () -> Void
    var onEnded: (Bool) -> Void

    @SwiftUI.Environment(\.flowDismiss) var flowDismiss

    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var edgeGestureRecognizer: UIScreenEdgePanGestureRecognizer!

    /// Bool that tracks active dragging to be used to track tool bar position for overlappingTopInset
    @Published var isUpdating: Bool = false

    private var isPastThreshold: Bool = false
    private var impactGenerator: UIImpactFeedbackGenerator

    fileprivate var view: UIView? {
        didSet {
            panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
            view?.addGestureRecognizer(panGestureRecognizer)

            edgeGestureRecognizer.view?.removeGestureRecognizer(edgeGestureRecognizer)
            view?.addGestureRecognizer(edgeGestureRecognizer)

            view?.clipsToBounds = true
        }
    }

    fileprivate var scrollView: UIScrollView? {
        didSet {
            if let recognizer = scrollView?.panGestureRecognizer {
                panGestureRecognizer.shouldRequireFailure(of: recognizer)
                edgeGestureRecognizer.shouldRequireFailure(of: recognizer)
            }
        }
    }

    init(threshold: Double, onPan: @escaping (CGPoint) -> Void, isEnabled: Bool, isDismissing: Bool, onDismiss: @escaping () -> Void, onEnded: @escaping (Bool) -> Void) {
        self.threshold = threshold

        self.onPan = onPan
        self.isEnabled = isEnabled
        self.isDismissing = isDismissing
        self.onDismiss = onDismiss
        self.onEnded = onEnded

        self.impactGenerator = UIImpactFeedbackGenerator(style: .medium)

        super.init()

        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureUpdated(recognizer:)))
        self.panGestureRecognizer.delegate = self
        self.panGestureRecognizer.isEnabled = isEnabled

        self.edgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeGestureUpdated(recognizer:)))
        self.edgeGestureRecognizer.edges = [.left]
        self.edgeGestureRecognizer.delegate = self
        self.edgeGestureRecognizer.isEnabled = isEnabled

        self.panGestureRecognizer.require(toFail: self.edgeGestureRecognizer)
    }

    @objc
    private func edgeGestureUpdated(recognizer: UIScreenEdgePanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let offset = recognizer.translation(in: view)
        update(offset: offset, isEdge: true, hasEnded: recognizer.state == .ended)
    }

    @objc
    private func panGestureUpdated(recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let offset = recognizer.translation(in: view)

        update(offset: offset, isEdge: false, hasEnded: recognizer.state == .ended)
    }

    private func update(offset: CGPoint, isEdge: Bool, hasEnded: Bool) {
        isUpdating = true
        onPan(offset)

        let shouldDismiss = offset.y > threshold || (offset.x > threshold && isEdge)
        if shouldDismiss != isPastThreshold && shouldDismiss {
            impactGenerator.impactOccurred()
        }

        isPastThreshold = shouldDismiss

        if hasEnded {
            if shouldDismiss {
                isEnabled = false
                onDismiss()
                isPastThreshold = false
            } else {
                isUpdating = false
            }
            onEnded(shouldDismiss)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer, let scrollView = scrollView else { return true }

        guard panGestureRecognizer.translation(in: scrollView).y > 0 else { return false }

        return scrollView.contentOffset.y - 5 <= -scrollView.contentInset.top
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        guard (gestureRecognizer == panGestureRecognizer || gestureRecognizer == panGestureRecognizer), let scrollView = scrollView else {
            return true
        }

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
    func onInteractiveDismissGesture(threshold: Double = 50, isEnabled: Bool = true, isDismissing: Bool = false, onDismiss: @escaping () -> Void, onPan: @escaping (CGPoint) -> Void = { _ in }, onEnded: @escaping (Bool) -> Void = { _ in }) -> some View {
        InteractiveDismissContainer(threshold: threshold, onPan: onPan, isEnabled: isEnabled, isDismissing: isDismissing, onDismiss: onDismiss, onEnded: onEnded, content: self)
    }
}
