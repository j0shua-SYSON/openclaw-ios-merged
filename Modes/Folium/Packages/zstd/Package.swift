// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zstd",
    platforms: [
        .macOS(.v10_10), .iOS(.v9), .tvOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "libzstd",
            targets: [ "libzstd" ]),
        .library(
            name: "libzstdwrapper",
            targets: [ "libzstdwrapper" ]),
        .library(
            name: "libseekable_format",
            targets: [ "libseekable_format" ])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "libseekable_format",
            dependencies: [ "libzstd" ],
            path: "contrib",
            exclude: [ "seekable_format/examples", "seekable_format/tests" ],
            sources: [ "seekable_format" ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath(".."),
                .headerSearchPath("../lib/common"),
                .define("ZSTD_STATIC_LINKING_ONLY")
            ]),
        .target(
            name: "libzstd",
            path: "lib",
            sources: [ "common", "compress", "decompress", "dictBuilder" ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]),
        .target(
            name: "libzstdwrapper",
            path: "zlibWrapper",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("../lib"),
                .headerSearchPath("../lib/common"),
                .headerSearchPath("../programs"),
                // zstd_zlibwrapper.c uses the advanced API (ZSTD_customMem, ZSTD_CCtx_params,
                // ZSTD_createCCtxParams, ...) which zstd.h gates behind this define.
                .define("ZSTD_STATIC_LINKING_ONLY")
            ])
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
