// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ResponsiveTextField",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "ResponsiveTextField",
            targets: ["ResponsiveTextField"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
            from: "1.17.2"
        ),
        .package(
            url: "https://github.com/pointfreeco/combine-schedulers.git",
            from: "1.0.2"
        )
    ],
    targets: [
        .target(
            name: "ResponsiveTextField",
            dependencies: [
                .product(name: "CombineSchedulers", package: "combine-schedulers")
            ],
        ),
        .testTarget(
            name: "ResponsiveTextFieldTests",
            dependencies: [
                "ResponsiveTextField",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: ["__Snapshots__"]
        )
    ]
)
