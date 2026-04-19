// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "glassbook-mcp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "glassbook-mcp", targets: ["GlassbookMCP"]),
    ],
    targets: [
        .executableTarget(
            name: "GlassbookMCP",
            path: "Sources/GlassbookMCP"
        ),
        .testTarget(
            name: "GlassbookMCPTests",
            dependencies: ["GlassbookMCP"],
            path: "Tests/GlassbookMCPTests"
        ),
    ]
)
