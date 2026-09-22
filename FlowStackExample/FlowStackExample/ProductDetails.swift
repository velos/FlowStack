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

    /// Whether the close button is a toolbar item, which takes a navigation stack to host it,
    /// or is placed by hand over the image.
    var usesNavigationStack = true

    /// Whether to show the safe area the content is laid out for, to watch it during a pull.
    var showsSafeArea = false

    var body: some View {
        Group {
            if usesNavigationStack {
                NavigationContainer {
                    content
                        // The system positions toolbar items clear of system UI wherever it
                        // is, e.g. beside iPhone Duo's camera and status items, which sit in
                        // the trailing corner rather than along the top edge.
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                toolbarCloseButton
                                    .opacity(opacity)
                            }
                        }
                        .hiddenNavigationBarBackground()
                }
            } else {
                content
            }
        }
        .withFlowAnimation {
            opacity = 0.78
        } onDismiss: {
            opacity = 0
        }
    }

    /// The system draws a button with the close role itself, but only in a toolbar.
    @ViewBuilder
    private var toolbarCloseButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) {
                flowDismiss()
            }
        } else {
            roundCloseButton
        }
    }

    private var roundCloseButton: some View {
        Button(action: { flowDismiss() }, label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .darkGray))
                .padding(8)
                .background {
                    Circle()
                        .foregroundStyle(Color(uiColor: .white))
                }
        })
        .accessibilityLabel("Close")
    }

    private var content: some View {
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
                        .overlay(alignment: .topTrailing) {
                            if !usesNavigationStack {
                                // Placed by hand, so it has to keep clear of system UI itself,
                                // on whichever edges that is.
                                roundCloseButton
                                    .padding(.top, proxy.safeAreaInsets.top + 12)
                                    .padding(.trailing, proxy.safeAreaInsets.trailing + 12)
                                    .opacity(opacity)
                            }
                        }
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
            .overlay(alignment: .bottom) {
                if showsSafeArea {
                    SafeAreaReadout(insets: proxy.safeAreaInsets, size: proxy.size)
                        .padding(.bottom, 12)
                }
            }
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

private extension View {
    /// Keeps the navigation bar transparent so the image shows through it.
    @ViewBuilder
    func hiddenNavigationBarBackground() -> some View {
        if #available(iOS 16.0, *) {
            toolbarBackground(.hidden, for: .navigationBar)
        } else {
            self
        }
    }
}

/// Shows the safe area a view is laid out for, and turns red while it differs from what it
/// was at rest. A destination's content should keep the same safe area while it is pulled
/// around; when it doesn't, the content reflows under the finger.
private struct SafeAreaReadout: View {
    let insets: EdgeInsets
    let size: CGSize

    /// The insets once they first held still, after the destination had finished presenting.
    @State private var restingInsets: EdgeInsets?

    private var hasChanged: Bool {
        guard let resting = restingInsets else { return false }
        return abs(resting.top - insets.top) > 0.5 || abs(resting.leading - insets.leading) > 0.5 ||
            abs(resting.bottom - insets.bottom) > 0.5 || abs(resting.trailing - insets.trailing) > 0.5
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("safe area  \(Self.describe(insets))")
            if hasChanged, let resting = restingInsets {
                Text("at rest  \(Self.describe(resting))")
            }
            Text("content  \(size.width, specifier: "%.0f") × \(size.height, specifier: "%.0f")")
        }
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hasChanged ? Color.red : Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
        .task(id: insets) {
            // Only the first time: holding a pull still mustn't pass for being at rest.
            guard restingInsets == nil else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled, restingInsets == nil {
                restingInsets = insets
            }
        }
    }

    private static func describe(_ insets: EdgeInsets) -> String {
        String(format: "T %.0f  L %.0f  B %.0f  R %.0f", insets.top, insets.leading, insets.bottom, insets.trailing)
    }
}

/// What the search button presents. There is nothing to it: the search is the destination.
struct SearchRequest: Hashable {}

/// A search over the products, presented from the button floating over the flow stack.
struct ProductSearch: View {
    @Environment(\.flowDismiss) var flowDismiss
    @State private var query = ""

    private var results: [Product] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? Product.allProducts : Product.allProducts.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationContainer {
            List(results) { product in
                VStack(alignment: .leading) {
                    Text(product.name)
                    Text(product.released)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Products")
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { flowDismiss() }
                    } else {
                        Button("Done") { flowDismiss() }
                    }
                }
            }
        }
    }
}

struct ProductDetails_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetails(product: .appleII)
    }
}
