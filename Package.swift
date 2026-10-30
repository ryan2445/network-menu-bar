// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "network-menu-bar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "network-menu-bar", targets: ["network-menu-bar"])
  ],
  targets: [
    .executableTarget(
      name: "network-menu-bar",
      path: ".",
      exclude: [
        "Network Menu Bar.app",
        "build-app.sh",
        "Info.plist",
        "README.md",
        "scripts",
        "dist"
      ]
    )
  ]
)
