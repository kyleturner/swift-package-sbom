// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-package-sbom-generator",
    platforms: [
        .macOS("10.15.4")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CycloneDX",
            targets: ["CycloneDX"]),
        .executable(name: "swift-package-sbom", targets: ["swift-package-sbom"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-package-manager.git",
                 revision: "swift-5.7.2-RELEASE"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 .upToNextMinor(from: "1.0.3")),
//        .package(url: "https://github.com/SwiftDocOrg/Git.git", .upToNextMinor(from: "0.0.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "swift-package-sbom",
            dependencies: [
                .product(name: "SwiftPMDataModel-auto", package: "swift-package-manager"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "CycloneDX",
//                "Git",
            ]),
        .target(
            name: "CycloneDX",
            dependencies: [
            ]),
        .testTarget(
            name: "CycloneDXTests",
            dependencies: [
                .target(name: "CycloneDX"),
            ]),
    ]
)
