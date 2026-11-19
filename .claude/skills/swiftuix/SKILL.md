---
name: swiftuix
description: >
  Reference for SwiftUIX (github.com/SwiftUIX/SwiftUIX), the open-source library that fills
  SwiftUI's gaps with ports of UIKit/AppKit features: CocoaTextField, CocoaList, CocoaScrollView,
  CollectionView, PaginationView, SearchBar, ActivityIndicator, AppActivityView, ImagePicker,
  VisualEffectView, BlurEffectView, LinkPresentationView, WindowOverlay, Keyboard,
  navigation-bar styling, padding(.keyboard), and more. Use when writing or reviewing SwiftUI code
  that needs something SwiftUI lacks, when the user mentions SwiftUIX, or when adding SwiftUIX
  as a Swift Package dependency.
---

# SwiftUIX

SwiftUIX is a Swift package (MIT, by Vatsal Manot), not a runtime tool. This skill bundles its
README, its docs, its `Package.swift` and its full `Sources/` tree, pinned to tag `0.3.2`
(commit `3a99044`), so you can look up the real API instead of guessing it.

## Look up the API before you write code

- `README.md`: the UIKit → SwiftUI → SwiftUIX mapping table and short usage examples. Start here.
- `Documentation.md`: longer notes on specific components.
- `Sources/SwiftUIX/`: the public API. Grep it for a type or modifier before you use it, and
  check its `@available` and `#if os(...)` guards so you don't use an iOS-only view on macOS, or
  the other way round. For example: `grep -rn "struct CocoaTextField" Sources/`.
- `Sources/_SwiftUIX/`: internal helpers. Don't call these from app code.

Paths are relative to this skill's directory (`.claude/skills/swiftuix/`).

Rules:
- Use the platform's own API when SwiftUI already does the job for the app's deployment
  target (for example `.searchable` on iOS 15+, `ProgressView`, `ShareLink`, `LazyVGrid`).
  Use SwiftUIX only for what SwiftUI lacks or does badly.
- Never make up a SwiftUIX type or modifier. If grep doesn't find it, it doesn't exist.

## Adding it to an app

The library must be a package dependency of the app before `import SwiftUIX` builds.

Swift Package Manager (`Package.swift`):

```swift
dependencies: [
    .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.3.2"),
],
targets: [
    .target(name: "MyApp", dependencies: ["SwiftUIX"]),
]
```

Xcode project: File → Add Package Dependencies… → `https://github.com/SwiftUIX/SwiftUIX`, then add
the `SwiftUIX` product to the app target.

Requirements: Swift 5.10+ and Xcode 15.4+. Deployment targets: iOS 13, macOS 11, Mac Catalyst 13,
tvOS 13, watchOS 6 and visionOS 1.

## Updating this snapshot

To refresh it, clone the repo at a newer tag and replace `README.md`, `Documentation.md`,
`Package.swift`, `LICENSE` and `Sources/` here, then update the tag and commit above.
