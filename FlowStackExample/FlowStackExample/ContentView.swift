//
//  ContentView.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/27/23.
//

import SwiftUI
import FlowStack
import CachedAsyncImage

struct ContentView: View {
    var body: some View {
        ProductList()
    }
}

struct ProductList: View {
    @State var path = FlowPath()

    var body: some View {
        FlowStack(path: $path, animation: .bouncy) {
            ScrollView {
                LazyVStack(alignment: .center, spacing: 24, pinnedViews: [], content: {
                    ForEach(Product.allProducts) { product in
                        FlowLink(value: product,
                                 configuration: .init(
                                    animateFromAnchor: true,
                                    transitionFromSnapshot: true,
                                    cornerRadius: 24,
                                    cornerStyle: .continuous,
                                    shadowRadius: 0,
                                    shadowColor: nil,
                                    shadowOffset: .zero,
                                    zoomStyle: .scaleHorizontally)) {
                                        ProductView(product: product)
                                    }
                    }
                })
                .padding(.horizontal)
            }
            .flowDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
        }
    }
}

struct ProductView: View {
    var product: Product

    var body: some View {
        image(url: product.imageUrl)
            .aspectRatio(4 / 3, contentMode: .fill)
            .overlay(alignment: .topTrailing) {
                Text(product.name)
                    .font(.system(size: 48))
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                    .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func image(url: URL) -> some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(minHeight: 0)
        } placeholder: {
            Color(uiColor: .secondarySystemFill)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
