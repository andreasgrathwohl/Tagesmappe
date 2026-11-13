// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FrontstageCore",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [.library(name: "FrontstageCore", targets: ["FrontstageCore"])],
  targets: [
    .target(name: "FrontstageCore"),
    .testTarget(name: "FrontstageCoreTests", dependencies: ["FrontstageCore"]),
  ]
)
