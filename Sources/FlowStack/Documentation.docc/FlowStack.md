# ``FlowStack``

Stack-based navigation with zooming transitions and interactive pull-to-dismiss.

## Overview

FlowStack presents views by zooming them out of the view that was tapped, and dismisses them by zooming back into it, either programmatically or as the person drags the view away. Its API follows SwiftUI's `NavigationStack`: put the root view in a ``FlowStack``, present values with a ``FlowLink``, and say which view each type of value presents with ``SwiftUICore/View/flowDestination(for:destination:)``.

```swift
FlowStack {
    ScrollView {
        LazyVStack {
            ForEach(parks) { park in
                FlowLink(value: park, configuration: .init(cornerRadius: 24)) {
                    ParkRow(park: park)
                }
            }
        }
    }
    .flowDestination(for: Park.self) { park in
        ParkDetails(park: park)
    }
}
```

FlowStack works back to iOS 15. To present from code, or to see what's presented, give the stack a ``FlowPath`` binding.

## Topics

### Presenting views

- ``FlowStack``
- ``FlowLink``
- ``SwiftUICore/View/flowDestination(for:destination:)``
- ``FlowPath``

### Customizing the transition

- ``FlowLink/Configuration``
- ``FlowLink/ZoomStyle``
- ``FlowPresentationStyle``
- ``FlowLink/Activation``
- ``SwiftUICore/View/flowAnimationAnchor()``
- ``CustomSmoothAnimation``
- ``SwiftUICore/Animation/defaultFlow``

### Dismissing views

- ``FlowDismissAction``
- ``SwiftUICore/EnvironmentValues/flowDismiss``
- ``SwiftUICore/View/flowInteractiveDismissDisabled(_:)``

### Animating with the transition

- ``SwiftUICore/View/withFlowAnimation(onPresent:onDismiss:)``
- ``SwiftUICore/EnvironmentValues/flowAnimationDuration``

### Telling apart links that present the same value

- ``SwiftUICore/View/flowLinkID(_:)``

### Reading the stack's state

- ``SwiftUICore/EnvironmentValues/flowPath``
