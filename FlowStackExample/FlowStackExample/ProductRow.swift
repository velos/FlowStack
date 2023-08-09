//
//  ProductRow.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 7/24/23.
//

import SwiftUI
import CachedAsyncImage

struct ProductRow: View {
    var product: Product
    var cornerRadius: CGFloat

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

struct ProductRow_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LazyVStack {
                ProductRow(product: .appleII, cornerRadius: 24)
            }
        }

    }
}

/// A Product Row with view content outside the main image to demonstrate flowAnimationAnchor use case.
struct ProductRowV2: View {
    var product: Product
    var cornerRadius: CGFloat

    var body: some View {
        HStack {
            image(url: product.imageUrl)
                .flowAnimationAnchor() // <- Sets the given view as the transition animation origin.
            VStack(alignment: .leading) {
                Text(product.name)
                    .font(.title)
                Text(product.released)
                    .font(.subheadline)
                Spacer()
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(lineWidth: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func image(url: URL?) -> some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        } placeholder: {
            Color(uiColor: .secondarySystemFill)
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

