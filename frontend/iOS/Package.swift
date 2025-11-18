// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VibeZiOS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VibeZiOS",
            targets: ["VibeZiOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        .package(url: "https://github.com/livekit/client-sdk-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "VibeZiOS",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "LiveKit", package: "client-sdk-swift")
            ],
            path: ".",
            sources: [
                "VibeZApp.swift",
                "Models",
                "ViewModels",
                "Views",
                "Services",
                "Managers",
                "Components",
                "Extensions",
                "Enums"
            ]
        ),
    ]
)

