<img src="https://github.com/velos/FlowStack/blob/develop/Logo.svg" width="388"/>

**FlowStack** is a SwiftUI library for creating stack-based navigation with "flow" (aka "zooming") transition animations and interactive pull-to-dismiss gestures. FlowStack's API is modeled after Apple's [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack) making it easy and intuitive to add FlowStack to a new project or migrate an existing project currently using NavigationStack.

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

**Setting up and working with FlowStack is *very* similar to Apple's own NavigationStack:**

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

**Update the above example to use FlowStack:**

1. Add the root view inside the **FlowStack**.
   - For scrolling lists, use a ScrollView with a LazyVStack instead of a List for best animation results.
1. Add a **flowDestination(for:destination:)** modifier within the **FlowStack** hierarchy to associate a data type with it's corresponding destination view.
1. Initialize a **FlowLink** with...
   1. A value of the same data type handled by the corresponding **flowDestination(for:destination:)** modifier. 
   1. A **FlowLink.Configuration** to customize aspects of the transition. In the below example, a corner radius value is passed in to the configuration to match the corner radius of the ParkRow during transition.
   1. A view to serve as the content for the **FlowLink**. A common use case would be for this view to contain an image (or other elements) also present in the destination view.
  
In this example, similar to the NavigationStack, when a user selects a given flow link, the park value associated with the link is handled by the corresponding flow destination modifier with matching data type which adds the associated destination view to the stack (in this case, ParkDetails) and presents it via a "zooming" transiton animation. Views can be removed from the stack and dismissed programmatically (by calling the **FlowDismiss** action accessible via the Environment) or by the user dragging down to initiate an interactive dismiss gesture.

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

As with NavigationStack, FlowStack can support any combination of data and view types in it's stack. Simply add a new **flowDestination(for:destination:)** modifier to handle each data type you'd like to support via a given **FlowLink**.

## Manage naviagtion state

// TODO...
Example: Provide FlowPath binding (vs. internally managed path)

## Animation anchors

By defrault, flow transition animations originate from the bounds of the view provided as content to a FlowLink. However, depending on the given UI, it's sometimes preferable for the transition animation to originate from a subview within the FlowLink's content view.

A common use case is when a FlowLink's view contains an image along with additional view elements, but you only want the transition animation to emanate from the image, not the entire view containing the other elements. You can achieve this effect by adding a **.flowAnimationAnchor()** modifier to the view you want the transition animation to emanate from.

The below example adds the **.flowAnimationAnchor()** modifier to the image view. This allows the entire view inside the FlowLink to be tappable while constraining the transition animation to just the image.

```swift
FlowLink(value: park, configuration: .init(cornerRadius: cornerRadius)) {
    HStack {

        image(url: park.imageUrl)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .flowAnimationAnchor() // <- 💡 Sets the given view as the transition origin.

        VStack(alignment: .leading) {
            Text(park.name)
                .font(.title)
            Text(park.cityStateAddress)
                .font(.subheadline)
            Spacer()
        }
        Spacer()
    }
}
```

## Images

When displaying async images within a FlowLink, use [CachedAsyncImage](https://github.com/lorenzofiamingo/swiftui-cached-async-image) (included in the *FlowStack* library) instead of SwiftUI's provided [AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage). AsyncImage does not cache fetched images and as a result, will not load a previously fetched image fast enough to be included in transition snapshots (i.e. when `transitionFromSnapshot: true` in FlowLink Configuration).

[CachedAsyncImage docs](https://github.com/lorenzofiamingo/swiftui-cached-async-image) has a similar API to AsyncImage with the added ability to specify a cache for caching images. Setting a larger custom cache size is often necessary to get images to actually be cached; images must not be larger than 5% of the disk cache. [See discussion](https://developer.apple.com/documentation/foundation/nsurlsessiondatadelegate/1411612-urlsession#discussion)

```swift
// Custom cache to support larger image caching
extension URLCache {
    static let imageCache = URLCache(memoryCapacity: 512_000_000, diskCapacity: 10_000_000_000)
}

...

// Usage
CachedAsyncImage(url: url, urlCache: .imageCache) { image in
    image
        .resizable()
        .scaledToFill()
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
} placeholder: {
    Color(uiColor: .secondarySystemFill)
}
```

## Contribute

We welcome any contributions. Please read the [Contribution Guide](https://github.com/HeroTransitions/Hero/wiki/Contribution-Guide).
