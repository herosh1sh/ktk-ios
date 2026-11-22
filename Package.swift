// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTKApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "KTKApp", targets: ["KTKApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/realm/SwiftProtobuf.git", from: "1.27.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/keychain/KeychainAccess.git", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "KTKApp",
            dependencies: [
                "Alamofire",
                "CryptoSwift",
                "KeychainAccess"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "KTKAppTests",
            dependencies: ["KTKApp"],
            path: "Tests"
        ),
    ]
)