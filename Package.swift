// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlowStack",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "FlowStack",
            targets: ["FlowStack"]),
    ],
    targets: [
        .target(
            name: "FlowStack",
            resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(
            name: "FlowStackTests",
            dependencies: ["FlowStack"]),
    ]
)
