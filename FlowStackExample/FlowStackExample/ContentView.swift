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

    @AccessibilityFocusState private var isFocused: Bool
    @State var hideMacs: Bool = false
    var body: some View {
        FlowStack {
            ScrollView {
                Group {
                    if horizontalSizeClass == .compact {
                        LazyVStack(alignment: .center, spacing: 24, pinnedViews: [], content: {
                            content
                                .accessibilityRespondsToUserInteraction(true)
                                .accessibilityElement(children: .contain)
                        })

                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], alignment: .center, spacing: 16, content: {
                            content
                                .accessibilityRespondsToUserInteraction(true)
                                .accessibilityElement(children: .contain)
                        })
                    }
                }
                .accessibilityHidden(hideMacs)
                .padding(.horizontal )
            }
            .zIndex(0)
            .flowDestination(for: Product.self) { product in
                ProductDetails(product: product)
                    .accessibilityElement(children: .contain)
                    .accessibilityRespondsToUserInteraction(true)
                    .accessibilityLabel("ProductDetails from flowDestination in contentView")
                    .onAppear{
                        isFocused = true
                        print("hideMacs  true")
                        hideMacs = true
                    }
                    .onDisappear {
                        print("hideMacs  false")
                        hideMacs = false
                    }


            }
            // Zindex for accessibility Interactions
            .zIndex(1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FlowStack from contentView")
        .allowsHitTesting(!hideMacs)

    }


    var content: some View {
        ForEach(Product.allProducts) { product in
            FlowLink(value: product, configuration: .init(cornerRadius: cornerRadius)) {
                ProductRow(product: product, cornerRadius: cornerRadius)
                    .accessibilityElement(children: .combine)
            }
            .contentShape(Rectangle())
            .border(.red)
            .accessibilityRespondsToUserInteraction(true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Product \(product.name)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
