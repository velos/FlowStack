import SwiftUI
import XCTest

/// Runs real SwiftUI lifecycle and representable updates in a window. Each test owns
/// its window and closes it explicitly; no simulator app state is shared between tests.
@MainActor
final class HostedView<Content: View> {
    let controller: UIHostingController<Content>
    private let window: UIWindow

    init(_ content: Content) {
        controller = UIHostingController(rootView: content)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
    }

    func close() {
        controller.view.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }
}

extension XCTestCase {
    /// Yield to SwiftUI until the observable result arrives, not for a presumed
    /// number of frames. The timeout only bounds a failing test.
    @MainActor
    func waitFor(_ description: String, file: StaticString = #filePath, line: UInt = #line, until condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !condition() {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                XCTFail("Timed out waiting for \(description)", file: file, line: line)
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
