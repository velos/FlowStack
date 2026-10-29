import SwiftUI
import FlowStack
@main
struct FlowStackExampleApp: App {
    @StateObject var model = PlacementModel()
    var body: some Scene {
        WindowGroup {
            PlacementFixture(model: model)
                .task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                        for window in scene.windows where window.isKeyWindow {
                            dumpPlacement(window, tag: "ROOT")
                            activateLink(window)
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            dumpPlacement(window, tag: "DEST")
                            if let root = window.rootViewController {
                                print("AFTER AUTOMATIC PLACEMENT")
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                dumpPlacement(window, tag: "REFRESHED")
                            }
                        }
                    }
                }
        }
    }
}
func activateLink(_ view: UIView) {
    if let control = view as? UIControl {
        for target in control.allTargets {
            let selector = NSSelectorFromString("onTouchUpInside")
            if let object = target as? NSObject, object.responds(to: selector) { object.perform(selector); return }
        }
    }
    view.subviews.forEach(activateLink)
}
func dumpPlacement(_ view: UIView, tag: String, indent: String = "") {
    print("PLACEMENT \(tag) \(indent)\(type(of: view)) frame=\(view.frame) safe=\(view.safeAreaInsets)")
    view.subviews.forEach { dumpPlacement($0, tag: tag, indent: indent + " ") }
}
final class PlacementModel: ObservableObject {
    @Published var path = FlowPath()
}

struct PlacementFixture: View {
    @ObservedObject var model: PlacementModel
    var body: some View {
        FlowStack(path: $model.path) {
            NavigationStack {
                ScrollView {
                    FlowLink(value: "destination", configuration: .init(presentationStyle: .fullScreen)) {
                        Text("Open").frame(width: 200, height: 150).background(.blue)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Root") {} }
                    ToolbarItem(placement: .topBarTrailing) { Button("Share") {} }
                }
            }
            .flowDestination(for: String.self) { _ in
                NavigationStack {
                    ScrollView { Text("Destination").frame(maxWidth: .infinity) }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { Button("Close") {} }
                            ToolbarItem(placement: .topBarTrailing) { Button("Share") {} }
                        }
                }
            }
        }
    }
}

func refreshBars(_ controller: UIViewController) {
    if let nav = controller as? UINavigationController {
        nav.setNavigationBarHidden(true, animated: false)
        nav.setNavigationBarHidden(false, animated: false)
    }
    controller.children.forEach(refreshBars)
}
