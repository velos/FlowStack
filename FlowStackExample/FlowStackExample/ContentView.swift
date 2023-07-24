//
//  ContentView.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/27/23.
//

import SwiftUI
import FlowStack

struct ContentView: View {
    let cornerRadius: CGFloat = 24

    var body: some View {
        FlowStack {
            ScrollView {
                LazyVStack(alignment: .center, spacing: 24, pinnedViews: [], content: {
                    ForEach(Product.allProducts) { product in
                        FlowLink(value: product, configuration: .init(cornerRadius: cornerRadius)) {
                            ProductRow(product: product, cornerRadius: cornerRadius)
                        }
                    }
                })
                .padding(.horizontal)
            }
            .flowDestination(for: Product.self) { product in
                ProductDetails(product: product)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
