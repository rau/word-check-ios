// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "WordCheckCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "WordCheckCore", targets: ["WordCheckCore"])],
    targets: [
        .target(name: "WordCheckCore", path: "WordCheck",
                exclude: ["App.swift", "BoardView.swift", "GameController.swift", "Data", "Assets.xcassets", "Info.plist", "Privacy.txt", "PrivacyInfo.xcprivacy"],
                sources: ["Game.swift", "Dictionary.swift"]),
        .testTarget(name: "WordCheckCoreTests", dependencies: ["WordCheckCore"])
    ]
)
