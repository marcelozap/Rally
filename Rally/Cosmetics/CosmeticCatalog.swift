import Foundation

/// In-memory catalog of all cosmetics known to the running app.
///
/// Loads from `Resources/cosmetics.json` on init. Hot-reload from a remote
/// URL can be layered on later by exposing `load(from:)`.
final class CosmeticCatalog {
    static let shared = CosmeticCatalog()

    private(set) var all: [Cosmetic] = []
    private var byID: [Cosmetic.ID: Cosmetic] = [:]

    private init() {
        loadBundled()
    }

    func cosmetic(id: Cosmetic.ID) -> Cosmetic? { byID[id] }

    func cosmetics(of kind: Cosmetic.Kind) -> [Cosmetic] {
        all.filter { $0.kind == kind }
    }

    // MARK: Loading

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "cosmetics", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // No catalog yet — fall back to a single default skin so the game
            // is still playable in a fresh checkout.
            all = [Self.defaultSkin]
            byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            return
        }
        do {
            all = try JSONDecoder().decode([Cosmetic].self, from: data)
            byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        } catch {
            all = [Self.defaultSkin]
            byID = [Self.defaultSkin.id: Self.defaultSkin]
        }
    }

    private static let defaultSkin = Cosmetic(
        id: "default.neon.cyan",
        kind: .ballSkin,
        displayName: "Cyan Pulse",
        rarity: .common,
        unlock: .freeAtLaunch,
        textureName: nil,
        particleName: nil,
        tint: CodableColor(r: 0, g: 1, b: 1, a: 1),
        modifiers: nil
    )
}
