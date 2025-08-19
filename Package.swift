// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WechatSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "WechatSDK", targets: ["WechatSDK"]),
    ],
    targets: [
        // 1. 引入官方 xcframework
        .binaryTarget(
            name: "WechatOpenSDK",
            path: "Sources/WechatOpenSDK-XCFramework.xcframework"),
        // 2. 包一层 Wrapper，暴露给 Swift
        .target(
            name: "WechatSDK",
            dependencies: ["WechatOpenSDK"],
            path: "Sources/WechatWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("SWIFT_PACKAGE")
            ],
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3"),
                .linkedLibrary("z"),
                .linkedLibrary("c++")
            ]
        ),
        // Swift API 封装
        .target(
            name: "WechatManager",
            dependencies: ["WechatSDK"],
            path: "Sources/WechatManager"
        )
    ]
)
