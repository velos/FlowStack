import SwiftUI
import FlowStack

struct ContentView: View {

    @State var path = FlowPath()

    enum Test: CaseIterable, Hashable, CustomStringConvertible {
        case interactiveScrollView
        case noScroll
        case disableInteractiveDismiss

        var description: String {
            switch self {
            case .interactiveScrollView:
                return "Interactive Scroll Dismiss"
            case .noScroll:
                return "No Scroll Test"
            case .disableInteractiveDismiss:
                return "Disable Dismiss"
            }
        }
    }

    var body: some View {
        FlowStack(path: $path, overlayAlignment: .bottomTrailing) {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 20, alignment: .top), .init(.adaptive(minimum: 150), spacing: 20, alignment: .top)], alignment: .center, spacing: 20) {
                    ForEach(Test.allCases, id: \.self) { test in
                        FlowLink(value: test, configuration: .init(cornerRadius: 16)) {
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .foregroundColor(Color(.secondarySystemFill))
                                    .aspectRatio(3 / 4, contentMode: .fill)
                                    .flowAnimationAnchor()
                                Text(test.description)
                                    .font(.subheadline)
                                    .background(Color.purple)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(30)
                        }
                    }
                }
            }
            .background(Color.purple)
            .flowDestination(for: Test.self) { test in
                switch test {
                case .interactiveScrollView:
                    InteractiveScrollViewDismissTest(path: path)
                case .noScroll:
                    NoScrollTest(path: path)
                case .disableInteractiveDismiss:
                    DisableInteractiveDismissTest()
                }
            }
            .flowDestination(for: FloatingTest.self) { _ in
                Text("TESTING CART")
            }
        } overlay: {
            FlowLink(value: FloatingTest.destination, configuration: .init(cornerRadius: 25, shadowRadius: 10, shadowColor: .black.opacity(0.3))) {
                Image(systemName: "cart.fill")
                    .padding()
                    .background(Circle().foregroundColor(.orange))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 10)
            }
            .padding()
        }
    }
}
