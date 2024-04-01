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
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fill)
            .overlay {
                image(url: product.imageUrl)
                    .allowsHitTesting(false) // https://stackoverflow.com/a/74711565
            }
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
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
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
