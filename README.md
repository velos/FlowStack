<img src="https://temp.tejen.net/23flowstack/logo.svg" width="388"/>

**FlowStack** is a SwiftUI library for creating stack-based navigation with "zooming" transition animations and interactive dismiss functionality. FlowStack's API is modeled after Apple's [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack) making it easy and intuitive to add to any new SwiftUI app or migrate from any existing app currently using NavigationStack.

[![License](https://img.shields.io/badge/License-MIT-black.svg)](https://github.com/velos/FlowStack/blob/develop/LICENSE)
![Xcode 15.0+](https://img.shields.io/badge/Xcode-14.0+-blue.svg)
![iOS 17.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg)

<img width="263" alt="image" src="https://temp.tejen.net/23flowstack/demo.gif">

## Installation

To integrate using Apple's Swift package manager, add the following as a dependency to your `Package.swift`:

```
.package(url: "https://github.com/velos/FlowStack.git", .branch("develop"))
```

## Getting Started

Here's an example from [Apple's NavigationStack documentation](https://developer.apple.com/documentation/swiftui/navigationstack#overview) that allows a user to navigate to a detail screen when tapping an item in a list. In this case, the `ParkDetails` screen transitions in by sliding in from the righthand side of the screen in a classic "push" navigation animation.

```swift
NavigationStack {
    List(parks) { park in
        NavigationLink(park.name, value: park)
    }
    .navigationDestination(for: Park.self) { park in
        ParkDetails(park: park)
    }
}
```

Updating the above example to use FlowStack looks like this...
  - ⚠️ NOTE: FlowStack's transition animation currently works best with `ScrollView { LazyVStack { ForEach ... }}}` vs `List`. 

```swift
FlowStack {
    ScrollView {
        LazyVStack {
           ForEach(parks) { park in
               FlowLink(value: park, configuration: .init(cornerRadius: cornerRadius)) {
                    ParkRow(park: park, cornerRadius: cornerRadius)
                }
            }
            .flowDestination(for: Park.self) { park in
                ParkDetails(park: park)
            }
        }
        .padding(.horizontal)
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
| transitionFromSnapshot | Bool | **`true`**: auto-capture a still image of the contents of the given `FlowLink` upon navigation, to use as a starting point for the flow animation. :bulb: **This is necessary when your `FlowLink` views contain an image, to avoid distortion during animation.** Also see: [Usage Notes](https://github.com/velos/FlowStack/#usage-notes) |
| animateFromAnchor     | Bool     | This should be used in conjunction with `transitionFromSnapshot` to expand an image view upon navigation flow     |
| cornerRadius   | CGFloat | Set a beginning radius. Used as a starting point for the flow animation. |
| cornerStyle | [:link: RoundedCornerStyle](https://developer.apple.com/documentation/swiftui/roundedcornerstyle) | Use this in conjunction with `cornerRadius` to define the shape of the view's rounded rectangle's corners. |
| shadowRadius   |  CGFloat  |  Set the strength of the shadow beneath the given `FlowLink` view  |
| shadowColor    | Color     |  Define the color of a shadow, if applicable  |
| shadowOffset   | CGPoint   | .zero     |
| zoomStyle      | enum | `.scaleHorizontally` — *description* `.resize` — *description* |

## Usage Notes

⚠️ **When displaying images from the Internet within your FlowLink views, you may see animation distortion when navigating to new views.** To remedy this, you will need to use CachedAsyncImage in order to display any remote images in your FlowLink views, as well as add additional code to define a larger cache size, as shown below...

```
extension URLCache {
    // increase the default capacity to something usable
    static let imageCache = URLCache(memoryCapacity: 512_000_000, diskCapacity: 10_000_000_000)
}

// Usage
CachedAsyncImage(url: url, urlCache: .imageCache) { image in ... }
```

In addition, we recommend using the `transitionFromSnapshot` and `animateFromAnchor` parameters when displaying images in your FlowLink views. See [Configuration](https://github.com/velos/FlowStack/#configuration) above for details.

A working example of this approach can be seen in [ContentView.swift](https://github.com/velos/FlowStack/blob/develop/FlowStackExample/FlowStackExample/ContentView.swift) on the official FlowStack example project.

## Contribute

We welcome any contributions. Please read the [Contribution Guide](https://github.com/HeroTransitions/Hero/wiki/Contribution-Guide).
