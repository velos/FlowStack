//
//  ProductDetails.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/28/23.
//

import SwiftUI
import FlowStack
import CachedAsyncImage

struct ProductDetails: View {
    @Environment(\.flowDismiss) var flowDismiss
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
                                .padding(.leading, proxy.safeAreaInsets.leading)
                                .opacity(opacity)
                        })
                        .overlay(alignment: .topTrailing, content: {
                            Button(action: {
                                flowDismiss()
                            }, label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color(uiColor: .darkGray))
                                    .padding(10)
                                    .background {
                                        Circle()
                                            .foregroundStyle(Color(uiColor: .white))
                                    }
                            })
                            // The image extends under system UI, which isn't always along
                            // the top edge: iPhone Duo's camera and status items sit in
                            // the trailing corner and are reported as a trailing inset.
                            .padding(.top, proxy.safeAreaInsets.top + 12)
                            .padding(.trailing, proxy.safeAreaInsets.trailing + 12)
                            .opacity(opacity)
                        })
                        .accessibilitySortPriority(100)
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
                    .padding(.leading, proxy.safeAreaInsets.leading)
                    .padding(.trailing, proxy.safeAreaInsets.trailing)
                    .opacity(opacity)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAction(.escape) { flowDismiss() }
            }
            .ignoresSafeArea()
        }
        .withFlowAnimation {
            opacity = 0.78
        } onDismiss: {
            opacity = 0
        }
    }

    private func image(url: URL) -> some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, minHeight: 0)
                .accessibilityHidden(true)
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

struct ProductDetails_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetails(product: .appleII)
    }
}
