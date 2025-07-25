// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "YOCRWorker",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "YOCRWorker",
            targets: ["YOCRWorker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "YOCRWorker",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources/YOCRWorker"
        )
    ]
)
