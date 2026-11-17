// swift-tools-version: 5.9
// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "VauchiContract",
    platforms: [.iOS(.v15), .macOS(.v14)],
    products: [
        .library(name: "VauchiContract", targets: ["VauchiContract"]),
        .library(name: "CommandContract", targets: ["CommandContract"]),
        .library(name: "EventContract", targets: ["EventContract"])
    ],
    targets: [
        .target(name: "CommandContract", path: "Sources/CommandContract"),
        .target(name: "EventContract", path: "Sources/EventContract"),
        .target(
            name: "VauchiContract",
            dependencies: ["CommandContract", "EventContract"],
            path: "Sources/VauchiContract",
            resources: [.copy("schema")]
        ),
        .testTarget(
            name: "VauchiContractTests",
            dependencies: ["VauchiContract"],
            path: "Tests/VauchiContractTests"
        )
    ]
)
