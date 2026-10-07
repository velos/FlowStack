//
//  ContentView.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/27/23.
//

import SwiftUI
import FlowStack

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let cornerRadius: CGFloat = 24
    @State private var presentationStyle: FlowPresentationStyle = .automatic
    @State private var path = FlowPath()
    @StateObject private var detailOptions = DetailOptions()

    var body: some View {
        FlowStack(path: $path, overlayAlignment: .bottomTrailing) {
            // The navigation container goes inside the flow stack. Outside it, the
            // navigation bar would be drawn over presented destinations.
            NavigationContainer {
                ScrollView {
                    featured

                    Group {
                        if horizontalSizeClass == .compact {
                            LazyVStack(alignment: .center, spacing: 24, pinnedViews: [], content: {
                                content
                            })
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], alignment: .center, spacing: 16, content: {
                                content
                            })
                        }
                    }
                    .padding(.horizontal)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        presentationStyleMenu
                    }
                }
            }
            .flowDestination(for: SearchRequest.self) { _ in
                ProductSearch()
            }
            .flowDestination(for: Product.self) { product in
                ProductDetails(
                    product: product,
                    usesNavigationStack: detailOptions.usesNavigationStack,
                    showsSafeArea: detailOptions.showsSafeArea
                )
                    .accessibilityElement(children: .contain)
                    .accessibilityRespondsToUserInteraction(true)
                    .accessibilityLabel("ProductDetails from flowDestination in contentView")

            }
        } overlay: {
            // The overlay stays in front of whatever the flow stack presents, so a flow link
            // in it can present from anywhere in the stack. This one is only wanted over the
            // root, and fades out while anything is presented.
            if path.isEmpty {
                searchButton
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: path.isEmpty)
        // The search brings up the keyboard. Kept out of the flow stack's safe area, it
        // doesn't shrink the stack, and the zoom to and from the search button with it; the
        // destination keeps clear of the keyboard by itself.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityElement(children: .contain) 
    }

    private var searchButton: some View {
        FlowLink(value: SearchRequest(), configuration: .init(cornerRadius: 28, presentationStyle: presentationStyle)) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .glassCircle()
        }
        .accessibilityLabel("Search")
    }

    private var presentationStyleMenu: some View {
        Menu {
            Picker("Presentation Style", selection: $presentationStyle) {
                ForEach(FlowPresentationStyle.allCases, id: \.self) { style in
                    Label {
                        Text(style.title)
                        Text(style.explanation)
                    } icon: {
                        Image(systemName: style.symbolName)
                    }
                    .tag(style)
                }
            }

            Section("Detail") {
                Toggle(isOn: $detailOptions.usesNavigationStack) {
                    Label {
                        Text("Navigation Stack")
                        Text("Hosts the close button in a toolbar")
                    } icon: {
                        Image(systemName: "menubar.rectangle")
                    }
                }
                Toggle(isOn: $detailOptions.showsSafeArea) {
                    Label {
                        Text("Show Safe Area")
                        Text("Turns red if it changes during a pull")
                    } icon: {
                        Image(systemName: "ruler")
                    }
                }
            }
        } label: {
            Label("Options", systemImage: "rectangle.on.rectangle.angled")
        }
    }

    /// Products that are also in the list below, so each is presented by two flow links at
    /// once. A destination zooms out of whichever was tapped, and back into the same one.
    private var featured: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Identified differently to the rows of the list, which FlowStack scrolls
                    // to by their products' identifiers when it needs one of them created.
                    ForEach(Product.featuredProducts, id: \.imageUrl) { product in
                        FlowLink(value: product, configuration: .init(cornerRadius: 16, presentationStyle: presentationStyle)) {
                            FeaturedCard(product: product, cornerRadius: 16)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Featured product \(product.name)")
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 12)
    }

    var content: some View {
        ForEach(Product.allProducts) { product in
            FlowLink(value: product, configuration: .init(cornerRadius: cornerRadius, presentationStyle: presentationStyle)) {
                ProductRow(product: product, cornerRadius: cornerRadius)
                    .accessibilityElement(children: .combine)
            }
            .contentShape(Rectangle())
            .accessibilityRespondsToUserInteraction(true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Product \(product.name)")
        }
    }
}

/// How the detail view is put together. A flow destination is registered once, so its closure
/// reads these through a reference rather than capturing values that would go stale.
private final class DetailOptions: ObservableObject {
    @Published var usesNavigationStack = true
    @Published var showsSafeArea = false
}

private extension FlowPresentationStyle {
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .fullScreen: return "Full Screen"
        case .card: return "Card"
        }
    }

    var explanation: String {
        switch self {
        case .automatic: return "Full screen on iPhone, card on iPad"
        case .fullScreen: return "Always fills the screen"
        case .card: return "Floats wherever there's room"
        }
    }

    var symbolName: String {
        switch self {
        case .automatic: return "wand.and.stars"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        case .card: return "rectangle.center.inset.filled"
        }
    }
}

private extension View {
    /// A circle of glass on systems that have it, and of material before that.
    @ViewBuilder
    func glassCircle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .circle)
        } else {
            background(.regularMaterial, in: Circle())
        }
        #else
        background(.regularMaterial, in: Circle())
        #endif
    }
}

/// A navigation container, so a view can host toolbar items.
struct NavigationContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
