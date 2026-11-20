import Foundation

/// One habit that keeps a kid's germ from going around the house.
struct HouseholdStep: Codable, Hashable, Identifiable {
    let id: String
    let icon: String
    let families: [GermFamily]
    let title: LocalizedText
    let detail: LocalizedText
    let sources: [GermReference]
}

/// The house habits shown when a kid gets sick, and the official daycare rules.
struct HouseholdGuide: Codable {
    let steps: [HouseholdStep]
    let daycare: GermReference

    func steps(for family: GermFamily) -> [HouseholdStep] {
        steps.filter { $0.families.contains(family) }
    }

    static func load() -> HouseholdGuide? {
        guard let url = Bundle.main.url(forResource: "household", withExtension: "json"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HouseholdGuide.self, from: raw)
    }
}
