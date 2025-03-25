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

    var body: some View {
        FlowStack {
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
            .flowDestination(for: Product.self) { product in
                ProductDetails(product: product)
            }
        }
    }

    var content: some View {
        ForEach(Product.allProducts) { product in
            FlowLink(value: product, configuration: .init(cornerRadius: cornerRadius)) {
                ProductRow(product: product, cornerRadius: cornerRadius)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
