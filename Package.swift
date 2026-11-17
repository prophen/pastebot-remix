// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ClipboardRemix",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClipboardRemix", targets: ["ClipboardRemix"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "ClipboardCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "ClipboardRemix", dependencies: ["ClipboardCore"]),
        .executableTarget(name: "ClipboardChecks", dependencies: ["ClipboardCore", "CSQLite"], path: "Tests/ClipboardCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
