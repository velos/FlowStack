//
//  ProductDetailView.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/28/23.
//

import SwiftUI
import FlowStack

struct ProductDetailView: View {
    @Environment(\.flowDismiss) var flowDismiss
    var product: Product

    var body: some View {
        ScrollView {
            VStack {
                image(url: product.imageUrl)
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .overlay(alignment: .bottomLeading, content: {
                        Text(product.name)
                            .font(.system(size: 48))
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                            .padding()
                    })
                    .overlay(alignment: .topTrailing, content: {
                        Button(action: {
                            // TODO: Dismiss action from button not working as expected
                            flowDismiss.callAsFunction()
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color(uiColor: .darkGray))
                                .padding(10)
                                .background {
                                    Circle()
                                        .foregroundStyle(Color(uiColor: .lightGray))
                                }
                        })
                        .safeAreaPadding()
                        .padding(.vertical, 40) // TODO: Button placement should directly respect safe area (vs. aprox via padding)
                    })
                    .clipped()
                VStack(alignment: .leading, spacing: 40) {
                    Text(product.description)

                    VStack(alignment: .leading) {
                        stat(label: "Released", value: product.released)
                        separator
                        stat(label: "Price", value: product.price)
                        separator
                        stat(label: "Processor", value: product.processor)
                        separator
                        stat(label: "RAM Max", value: product.ramMax)
                        separator
                        VStack(alignment: .leading) {
                            stat(label: "Display", value: product.display)
                            separator
                            stat(label: "Storage", value: product.storage)
                            separator
                            stat(label: "OS", value: product.osVersion)
                        }
                    }
                    .padding()
                    .overlay(.quaternary, in: RoundedRectangle(cornerRadius: 24, style: /*@START_MENU_TOKEN@*/.continuous/*@END_MENU_TOKEN@*/).stroke())
                }
                .padding()
            }
        }
        .ignoresSafeArea()
    }

    private func image(url: URL) -> some View {
        // TODO: Maybe replace with caching async image to more quickly load image from cache when available.
        // This could help transition be more "snappy" as far as image loading.
        // https://github.com/lorenzofiamingo/swiftui-cached-async-image
        AsyncImage(url: url, scale: 1) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
        } placeholder: {
            Color(uiColor: .secondarySystemFill)
        }
    }

    private func stat(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Color.clear
                .frame(width: 100)
                .overlay(alignment: .topLeading) {
                    Text(label)
                        .fontWeight(.semibold)

                }
            Text(value)
        }
    }

    private var separator: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(.quaternary)
    }
}

#Preview {
    ProductDetailView(product: .appleII)
}
