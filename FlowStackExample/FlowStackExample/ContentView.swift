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

    var body: some View {
        FlowStack {
            // The navigation container goes inside the flow stack. Outside it, the
            // navigation bar would be drawn over presented destinations.
            NavigationContainer {
                ScrollView {
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
            .flowDestination(for: Product.self) { product in
                ProductDetails(product: product)
                    .accessibilityElement(children: .contain)
                    .accessibilityRespondsToUserInteraction(true)
                    .accessibilityLabel("ProductDetails from flowDestination in contentView")

            }
        }
        .accessibilityElement(children: .contain) 
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
        } label: {
            Label("Presentation Style", systemImage: "rectangle.on.rectangle.angled")
        }
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
