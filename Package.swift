// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "network-menu-bar",
  platforms: [
    .macOS(.v26)
  ],
  targets: [
    .executableTarget(
      name: "network-menu-bar",
      path: "."
    )
  ]
)
