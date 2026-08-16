// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ViaOpenAPIGeneration",
    platforms: [.macOS(.v10_15), .iOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator.git", exact: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "ViaGeneratedAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "via/Shared/Networking/OpenAPI"
        ),
    ]
)
