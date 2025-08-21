// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WechatSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "WechatSDK", targets: ["WechatSwift"]),
    ],
    targets: [
        // 1. 引入官方 xcframework
        .binaryTarget(
            name: "WechatOpenSDK",
            path: "Sources/WechatOpenSDK-NoPay.xcframework"),
//        .binaryTarget(
//            name: "WechatOpenSDK",
//            url: "https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.5_NoPay.zip",
//            checksum: "28f0eb2aae2ca35df6e545811890735fb8798cd31af99454a7ab2c203df43864"
//        ),
        // 2. 包一层 Wrapper，暴露给 Swift
        .target(
            name: "WechatOC",
            dependencies: ["WechatOpenSDK"],
            path: "Sources/WechatOC",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("SWIFT_PACKAGE")
            ],
            linkerSettings: [
                .linkedFramework("WebKit"),
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
            name: "WechatSwift",
            dependencies: ["WechatOC"],
            path: "Sources/WechatSwift"
        )
    ]
)
