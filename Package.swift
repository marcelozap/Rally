// swift-tools-version: 5.9
import PackageDescription

// The same Foundation-only files are compiled directly into the iOS app.
// This package makes their numerical and persistence contracts testable without Xcode.
let package = Package(
    name: "RallyCoachCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RallyCoachCore", targets: ["RallyCoachCore"])],
    targets: [
        .target(
            name: "RallyCoachCore",
            path: "Rally/Features/Coach",
            exclude: ["CoachView.swift", "CoachViewModel.swift", "Services/CoachVideoAnalyzer.swift", "Services/CoachVideoTransfer.swift"],
            sources: ["Core", "Services/CoachReportStore.swift"]
        ),
        .testTarget(
            name: "RallyCoachCoreTests",
            dependencies: ["RallyCoachCore"],
            path: "Tests/RallyCoachCoreTests"
        )
    ]
)
