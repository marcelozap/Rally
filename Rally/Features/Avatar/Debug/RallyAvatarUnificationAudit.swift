import Foundation

#if DEBUG
enum RallyAvatarUnificationAudit {
    struct Check: Identifiable {
        let id: String
        let passed: Bool
        let evidence: String
    }

    static func run(projectRoot: URL? = nil) -> [Check] {
        guard let root = projectRoot ?? inferProjectRoot() else {
            return [
                Check(
                    id: "A-0",
                    passed: false,
                    evidence: "Unable to infer project root for file-system audit."
                )
            ]
        }

        return [
            checkGameSceneHasNoAvatarPathFunctions(root: root),
            checkSingleAppearanceStore(root: root),
            checkSharedGeometryUsage(root: root),
            checkEquippedItemsFlowThroughAppearance(root: root),
            checkNoAlternateAvatarRenderer(root: root)
        ]
    }

    static func printReport(projectRoot: URL? = nil) {
        let checks = run(projectRoot: projectRoot)
        let passed = checks.filter(\.passed).count
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RALLY AVATAR UNIFICATION AUDIT  \(passed)/\(checks.count) passed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        checks.forEach { check in
            print("\(check.passed ? "PASS" : "FAIL") [\(check.id)] \(check.evidence)")
        }
    }

    private static func checkGameSceneHasNoAvatarPathFunctions(root: URL) -> Check {
        let gameScene = root.appendingPathComponent("Rally/Game/GameScene.swift")
        let text = read(gameScene)
        let forbidden = [
            "func athleticLegPath",
            "func athleticShortsPath",
            "func premiumTorsoPath",
            "func premiumHeadPath",
            "func premiumHairPath",
            "func premiumBackHairPath",
            "func friendlyMouthPath"
        ]
        let hits = forbidden.filter { text.contains($0) }
        return Check(
            id: "A-1",
            passed: hits.isEmpty,
            evidence: hits.isEmpty
                ? "GameScene.swift contains zero avatar path builders; it calls RallyAvatarGeometry."
                : "GameScene.swift still contains avatar path builders: \(hits.joined(separator: ", "))."
        )
    }

    private static func checkSingleAppearanceStore(root: URL) -> Check {
        let files = swiftFiles(root: root)
        let occurrences = files.flatMap { file -> [String] in
            guard relative(file, root: root) != "Rally/Features/Avatar/Debug/RallyAvatarUnificationAudit.swift" else {
                return []
            }
            let text = read(file)
            guard text.contains("RallyAvatarAppearanceStore(") || text.contains("RallyAvatarAppearanceStore()") else {
                return []
            }
            return [relative(file, root: root)]
        }
        let appRootOwnsStore = occurrences.contains("Rally/App/RallyApp.swift")
        return Check(
            id: "A-2",
            passed: appRootOwnsStore && occurrences.count == 1,
            evidence: "Appearance store initializers: \(occurrences.joined(separator: ", ")). Expected only Rally/App/RallyApp.swift."
        )
    }

    private static func checkSharedGeometryUsage(root: URL) -> Check {
        let gameScene = read(root.appendingPathComponent("Rally/Game/GameScene.swift"))
        let swiftUIView = read(root.appendingPathComponent("Rally/Features/Avatar/RallyAvatarView.swift"))
        let gameUsesGeometry = gameScene.contains("RallyAvatarGeometry.")
        let swiftUIUsesGeometry = swiftUIView.contains("RallyAvatarGeometry.")
        return Check(
            id: "A-3",
            passed: gameUsesGeometry && swiftUIUsesGeometry,
            evidence: "GameScene uses shared geometry: \(gameUsesGeometry). RallyAvatarView uses shared geometry: \(swiftUIUsesGeometry)."
        )
    }

    private static func checkEquippedItemsFlowThroughAppearance(root: URL) -> Check {
        let appearance = read(root.appendingPathComponent("Rally/Features/Avatar/RallyAvatarAppearance.swift"))
        let home = read(root.appendingPathComponent("Rally/Features/Home/HomeView.swift"))
        let gameSession = read(root.appendingPathComponent("Rally/Features/Play/GameSessionView.swift"))
        let hasSlots = ["racket", "top", "shorts", "shoes", "socks", "headband"].allSatisfy { appearance.contains("var \($0): RallyGearReference?") }
        let homeSyncs = home.contains("avatarAppearanceStore.sync(from: avatar)")
        let gameFeedsScene = gameSession.contains("s.avatarAppearance = avatarAppearanceStore.appearance")
        return Check(
            id: "A-4",
            passed: hasSlots && homeSyncs && gameFeedsScene,
            evidence: "Slots present: \(hasSlots). Home syncs store: \(homeSyncs). GameScene receives store appearance: \(gameFeedsScene)."
        )
    }

    private static func checkNoAlternateAvatarRenderer(root: URL) -> Check {
        let forbiddenPaths = [
            "Rally/Features/Avatar/AvatarView.swift",
            "Rally/Features/Avatar/AvatarRealityKitView.swift",
            "Rally/Features/Avatar/Avatar3DModels.swift",
            "Rally/Assets.xcassets/MarcyAvatarReference.imageset"
        ]
        let remaining = forbiddenPaths.filter {
            FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path)
        }
        let project = read(root.appendingPathComponent("Rally.xcodeproj/project.pbxproj"))
        let forbiddenProjectRefs: [(name: String, needles: [String])] = [
            ("AvatarView.swift", [" path = AvatarView.swift;", "/* AvatarView.swift */"]),
            ("AvatarRealityKitView.swift", [" path = AvatarRealityKitView.swift;", "/* AvatarRealityKitView.swift */"]),
            ("Avatar3DModels.swift", [" path = Avatar3DModels.swift;", "/* Avatar3DModels.swift */"]),
            ("MarcyAvatarReference", ["MarcyAvatarReference.imageset", "MarcyAvatarReference.png"])
        ]
        let forbiddenRefs = forbiddenProjectRefs.compactMap { ref in
            ref.needles.contains(where: project.contains) ? ref.name : nil
        }
        return Check(
            id: "A-5",
            passed: remaining.isEmpty && forbiddenRefs.isEmpty,
            evidence: "Remaining files: \(remaining.joined(separator: ", ")). Project refs: \(forbiddenRefs.joined(separator: ", "))."
        )
    }

    private static func inferProjectRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let project = url.appendingPathComponent("Rally.xcodeproj")
            if FileManager.default.fileExists(atPath: project.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private static func swiftFiles(root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent("Rally"), includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private static func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func relative(_ url: URL, root: URL) -> String {
        url.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}
#endif
