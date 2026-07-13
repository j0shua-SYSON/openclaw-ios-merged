// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AntiqueKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "AntiqueKit", targets: ["AntiqueKit"]),
        .library(name: "ColourKit", targets: ["ColourKit"]),
        .library(name: "ConstraintKit", targets: ["ConstraintKit"]),
        .library(name: "ExtensionsKit", targets: ["ExtensionsKit"]),
        .library(name: "FontKit", targets: ["FontKit"]),
        .library(name: "OnboardingKit", targets: ["OnboardingKit"]),
        .library(name: "SettingsKit", targets: ["SettingsKit"])
    ],
    targets: [
        .target(name: "AntiqueKit", dependencies: ["ColourKit", "FontKit", "OnboardingKit", "SettingsKit"]),
        .target(name: "ColourKit"),
        .target(name: "ConstraintKit"),
        .target(name: "ExtensionsKit", dependencies: ["ColourKit"]),
        .target(name: "FontKit"),
        .target(name: "OnboardingKit", dependencies: ["ColourKit", "ConstraintKit", "ExtensionsKit", "FontKit"]),
        .target(name: "SettingsKit")
    ],
    swiftLanguageModes: [.v6]
)
