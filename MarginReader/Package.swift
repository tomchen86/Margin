// swift-tools-version: 6.2
import PackageDescription

// The reader that the app and the Quick Look extension share (ADR-0003).
let package = Package(
    name: "MarginReader",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "MarginReader", targets: ["MarginReader"])
    ],
    targets: [
        .target(name: "MarginReader")
    ]
)
