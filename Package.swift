// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Thread",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Thread", targets: ["ThreadApp"])],
    targets: [.executableTarget(name: "ThreadApp")]
)
