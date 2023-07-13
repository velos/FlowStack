//
//  ProductDetailView.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/28/23.
//

import SwiftUI
import FlowStack
import CachedAsyncImage

struct ProductDetailView: View {
    @Environment(\.flowDismiss) var flowDismiss
    @Environment(\.flowTransaction) var transaction

    @State var opacity: CGFloat = 0

    var product: Product

    var body: some View {
        GeometryReader { proxy in
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
                                .opacity(opacity)
                        })
                        .overlay(alignment: .topTrailing, content: {
                            Button(action: {
                                // TODO: Dismiss action from button not working as expected
                                flowDismiss()
                            }, label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color(uiColor: .darkGray))
                                    .padding(10)
                                    .background {
                                        Circle()
                                            .foregroundStyle(Color(uiColor: .lightGray))
                                    }
                            })
                            .padding(.horizontal, 12)
                            .padding(.vertical, proxy.safeAreaInsets.top + 12)
                            .opacity(opacity)
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
                    .opacity(opacity)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: {
            withTransaction(transaction) {
                opacity = 1
            }
        })
    }

    private func image(url: URL) -> some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
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

struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetailView(product: .appleII)
    }
}
