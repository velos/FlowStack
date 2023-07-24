<img src="https://temp.tejen.net/23flowstack/logo.svg" width="388"/>

**FlowStack** is a library for creating stack-based navigation using a flow layout in SwiftUI. It provides a data structure and animation layer to build upon SwiftUI's native NavigationStack – making it easy for cards in a grid to expand into new screens.

[![License](https://img.shields.io/badge/License-MIT-black.svg)](https://github.com/velos/FlowStack/blob/develop/LICENSE)
![Xcode 15.0+](https://img.shields.io/badge/Xcode-14.0+-blue.svg)
![iOS 17.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg)

<img width="263" alt="image" src="https://temp.tejen.net/23flowstack/demo.gif">

## Getting Started

The simplest way to use FlowStack is to create a blank new path, and simply use `FlowLink` items to get your navigation flowing.

```
@State var path = FlowPath()

var products: [Product]

var body: some View {
    FlowStack(path: $path) {
        ScrollView {
            LazyVStack(alignment: .center, spacing: 24, pinnedViews: [], content: {
                ForEach(products) { product in
                    FlowLink(value: product) {
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
```

In this example, a Product will be added to the `path` stack when its link is tapped, and navigation will flow into ProductDetailView for the tapped product.

Beyond products, FlowStack can support any combination of custom types in a single `FlowPath` stack. Simply define a new `.flowDestination(...)` for each type that you would like to support `FlowLink` items for.

## Usage Example

In the animated demo above, we achieve a "card" effect using `cornerRadius`.

In addition, our cards are comprised of an image, as defined in `ProductView`. Therefore, the navigation flow transition should begin with a snapshot of the card, which can then animate into a new view upon navigation. Use the `transitionFromSnapshot` and `animateFromAnchor` parameters in your FlowLink to make this happen.

```
FlowLink(value: product,
         configuration: .init(
            animateFromAnchor: true,
            transitionFromSnapshot: true,
            cornerRadius: 24,
            cornerStyle: .continuous,
            shadowRadius: 0,
            shadowColor: nil,
            shadowOffset: .zero,
            zoomStyle: .scaleHorizontally)
        ) {
            ProductView(product: product)
        }
```

## Configuration

Below is a reference for all configuration values that a `FlowLink` view can take on:

| Parameter | Type | Description |
| -------- | -------- | -------- |
| transitionFromSnapshot | Bool | **`true`**: auto-capture a still image of the contents of the given `FlowLink` upon navigation, to use as a starting point for the flow animation. :bulb: **This is necessary when your `FlowLink` views contain an image, to avoid distortion during animation.** |
| animateFromAnchor     | Bool     | This should be used in conjunction with `transitionFromSnapshot` to expand an image view upon navigation flow     |
| cornerRadius   | CGFloat | Set a beginning radius. Used as a starting point for the flow animation. |
| cornerStyle | [:link: RoundedCornerStyle](https://developer.apple.com/documentation/swiftui/roundedcornerstyle) | Use this in conjunction with `cornerRadius` to define the shape of the view's rounded rectangle's corners. |
| shadowRadius   |  CGFloat  |  Set the strength of the shadow beneath the given `FlowLink` view  |
| shadowColor    | Color     |  Define the color of a shadow, if applicable  |
| shadowOffset   | CGPoint   | .zero     |
| zoomStyle      | enum | `.scaleHorizontally` — *description* `.resize` — *description* |

## Installation

To integrate using Apple's Swift package manager, add the following as a dependency to your `Package.swift`:

```
.package(url: "https://github.com/velos/FlowStack.git", .branch("develop"))
```

## Contribute

We welcome any contributions. Please read the [Contribution Guide](https://github.com/HeroTransitions/Hero/wiki/Contribution-Guide).
