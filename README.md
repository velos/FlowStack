<img src="https://temp.tejen.net/23flowstack/logo.svg" width="388"/>

**FlowStack** is a SwiftUI library for creating stack-based navigation with "zooming" transition animations and interactive pull-to-dismiss gestures. FlowStack's API is modeled after Apple's [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack) making it easy and intuitive to add FlowStack to any new SwiftUI app or migrate from any existing app currently using NavigationStack.

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

**Setting up and working with FlowStack is *very* similar to Apple's own NavigationStack!**

For context, here's an example from [Apple's NavigationStack documentation](https://developer.apple.com/documentation/swiftui/navigationstack#overview) showing a basic NavigationStack setup that allows users to navigate to view a detail screen when tapping an item in a list. In this case, the `ParkDetails` transition slides in from the right with the familiar "push" navigation animation.

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

![NavigationStack Demo](https://github.com/velos/FlowStack/assets/11927517/39e7f0fa-d453-4afd-9950-53a6a50a1c84)

**Updating the above example to use FlowStack, the highlevel work flow is the same...**

1. Add the root view inside the **FlowStack**.
   - For scrolling lists, use a ScrollView with a LazyVStack instead of a List for best animation results.
1. Add a **flowDestination(for:destination:)** modifier within the **FlowStack** hierarchy to associate a data type with it's corresponding destination view.
1. Initialize a **FlowLink** with...
   1. A value of the same data type handled by the corresponding **flowDestination(for:destination:)** modifier. 
   1. A **FlowLink.Configuration** to customize aspects of the transition.
   1. A view to serve as the content for the **FlowLink**. A common use case would be for this view to contain an image (or other elements) also present in the destination view.
  
In this example, similar to the NavigationStack, when a user selects a given flow link, the park value associated with the link is fielded by the corresponding flow destination modifier which adds the associated destination view to the stack (in this case, ParkDetails) and presents it via a "zooming" transiton animation. Views can be removed from the stack and dismissed programmatically (by calling the **FlowDismiss** action accessible via the Environment) or by the user dragging down to initiate an interactive dismiss gesture.

```swift
FlowStack {
    ScrollView {
        LazyVStack {
           ForEach(parks) { park in
               FlowLink(value: park, configuration: .init(cornerRadius: cornerRadius)) {
                    ParkRow(park: park, cornerRadius: cornerRadius)
                }
            }
        }
        .padding(.horizontal)
    }
    .flowDestination(for: Park.self) { park in
        ParkDetails(park: park)
    }
}
```

![FlowStack Demo](https://github.com/velos/FlowStack/assets/11927517/254ed093-a1df-4891-a6fe-4ffda11198f4) 

## Navigate to different view types

As with NavigationStack, FlowStack can support any combination of data and view types in it's stack. Simply add a new **flowDestination(for:destination:)** modifier for each type that you would like to support **FlowLink** items for.

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

:warning: For any fetched images to be displayed within a FlowLink, please import and use `CachedAsyncImage` (included in the *FlowStack* library) instead of SwiftUI's provided `AsyncImage`. `AsyncImage` does not cache fetched images and as a result, will not load a previously fetched image fast enough to be included in transition snapshots (i.e. when `transitionFromSnapshot: true` in FlowLink Configuration)

```
extension URLCache {
    // increase the default capacity to something usable
    static let imageCache = URLCache(memoryCapacity: 512_000_000, diskCapacity: 10_000_000_000)
}

// Usage
CachedAsyncImage(url: url, urlCache: .imageCache) { image in ... }
```

For most transitions involving images within FlowLinks, you'll likely get the best results using the default values for `FlowLink.Configuration` in regards to `transitionFromSnapshot: true` and `animateFromAnchor: true`. See [Configuration](https://github.com/velos/FlowStack/#configuration) above for details.

A working example of this approach can be seen in [ContentView.swift](https://github.com/velos/FlowStack/blob/develop/FlowStackExample/FlowStackExample/ContentView.swift) on the official FlowStack example project.

## Contribute

We welcome any contributions. Please read the [Contribution Guide](https://github.com/HeroTransitions/Hero/wiki/Contribution-Guide).
