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
            ScrollView {
                presentationStylePicker
                    .padding()
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
                    .accessibilityElement(children: .contain)
                    .accessibilityRespondsToUserInteraction(true)
                    .accessibilityLabel("ProductDetails from flowDestination in contentView")

            }
        }
        .accessibilityElement(children: .contain) 
    }

    private var presentationStylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Presentation style", selection: $presentationStyle) {
                Text("Automatic").tag(FlowPresentationStyle.automatic)
                Text("Full Screen").tag(FlowPresentationStyle.fullScreen)
                Text("Card").tag(FlowPresentationStyle.card)
            }
            .pickerStyle(.segmented)

            Text("A card needs a wide flow stack, like an iPad or an unfolded iPhone Duo. Automatic only presents one on iPad.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
