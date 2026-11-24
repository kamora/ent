// swift-tools-version: 5.9
// The ent_opengl plugin for Swift Package Manager; macos/ent_opengl.podspec builds the same sources for CocoaPods.

import PackageDescription

let package = Package(
	name: "ent_opengl",
	platforms: [
		.macOS("10.15")
	],
	products: [
		.library(name: "ent-opengl", targets: ["ent_opengl"])
	],
	dependencies: [
		.package(name: "FlutterFramework", path: "../FlutterFramework")
	],
	targets: [
		.target(
			name: "ent_opengl",
			dependencies: [
				.product(name: "FlutterFramework", package: "FlutterFramework")
			]
		)
	]
)
