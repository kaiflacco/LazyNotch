// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LazyNotch",
    platforms: [.macOS("14.6")],
    targets: [
        .executableTarget(
            name: "LazyNotch",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
