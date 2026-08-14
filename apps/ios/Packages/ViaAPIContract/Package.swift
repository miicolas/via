// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ViaAPIContract",
    platforms: [
        .iOS(.v26),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "ViaAPIContract", targets: ["ViaAPIContract"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ViaAPIContract",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
    ]
)
