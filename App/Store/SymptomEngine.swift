import Foundation

/// One sign a parent can tick. Germs carry the same ids on the symptoms of their case file.
struct Symptom: Identifiable, Hashable {
    let id: String
    let symbol: String
    let title: String

    /// Trouble breathing is never matched to a germ: it sends the parent to the help lines.
    static let urgentID = "breathing"

    static var all: [Symptom] {
        [
            Symptom(id: "fever", symbol: "thermometer.medium", title: tr("Fever")),
            Symptom(id: "cough", symbol: "wind", title: tr("Cough")),
            Symptom(id: "runny_nose", symbol: "nose.fill", title: tr("Runny nose")),
            Symptom(id: "sore_throat", symbol: "flame.fill", title: tr("Sore throat")),
            Symptom(id: "vomiting", symbol: "arrow.uturn.up.circle.fill", title: tr("Vomiting")),
            Symptom(id: "diarrhea", symbol: "toilet.fill", title: tr("Diarrhea")),
            Symptom(id: "stomach_pain", symbol: "bolt.fill", title: tr("Stomach pain")),
            Symptom(id: "rash", symbol: "circle.hexagongrid.fill", title: tr("Rash or sores")),
            Symptom(id: "red_eye", symbol: "eye.fill", title: tr("Red eye")),
            Symptom(id: "ear_pain", symbol: "ear.fill", title: tr("Ear pain")),
            Symptom(id: "aches", symbol: "bandage.fill", title: tr("Body aches")),
            Symptom(id: "tired", symbol: "moon.zzz.fill", title: tr("Very tired")),
            Symptom(id: "headache", symbol: "brain.head.profile", title: tr("Headache")),
            Symptom(id: "itching", symbol: "sparkles", title: tr("Itching")),
            Symptom(id: "hoarse", symbol: "speaker.slash.fill", title: tr("Hoarse voice"))
        ]
    }

    static var urgent: Symptom {
        Symptom(id: urgentID, symbol: "lungs.fill", title: tr("Trouble breathing"))
    }

    /// The stored ids in the picker's order, with unknown ones dropped.
    static func ordered(_ ids: Set<String>) -> [Symptom] {
        (all + [urgent]).filter { ids.contains($0.id) }
    }
}

/// A germ that fits the ticked signs, and how well.
struct Suspect: Identifiable, Hashable {
    let germ: Germ
    let matched: Int
    /// True when the germ's telltale sign is among the ticked ones.
    let telltaleMatched: Bool

    var id: String { germ.id }
}

/// The suspects for a set of signs: the best fits first, then the rest.
struct Lineup {
    let chosen: Int
    let top: [Suspect]
    let others: [Suspect]

    /// True when the best fits cover every ticked sign.
    var isFull: Bool {
        top.first.map { $0.matched >= chosen } ?? false
    }
}

/// What tells one suspect from the others.
struct SuspectClue: Hashable {
    let isTelltale: Bool
    let text: String
}

/// Ranks the germs of the catalog against the signs a parent ticked. A guess for the logbook, never a diagnosis.
enum SymptomEngine {
    static func tags(of germ: Germ) -> Set<String> {
        Set(germ.symptoms.flatMap { $0.tags ?? [] })
    }

    static func lineup(for chosen: Set<String>, in germs: [Germ]) -> Lineup {
        let signs = chosen.subtracting([Symptom.urgentID])
        let rarities = Rarity.allCases
        var suspects: [Suspect] = []
        for germ in germs {
            let matched = tags(of: germ).intersection(signs).count
            guard matched > 0 else { continue }
            let telltale = germ.symptoms.contains { symptom in
                symptom.telltale == true && !Set(symptom.tags ?? []).isDisjoint(with: signs)
            }
            suspects.append(Suspect(germ: germ, matched: matched, telltaleMatched: telltale))
        }
        suspects.sort { first, second in
            if first.matched != second.matched { return first.matched > second.matched }
            if first.telltaleMatched != second.telltaleMatched { return first.telltaleMatched }
            let firstRank = rarities.firstIndex(of: first.germ.rarity) ?? 0
            let secondRank = rarities.firstIndex(of: second.germ.rarity) ?? 0
            if firstRank != secondRank { return firstRank < secondRank }
            return first.germ.number < second.germ.number
        }
        let best = suspects.first?.matched ?? 0
        return Lineup(chosen: signs.count, top: suspects.filter { $0.matched == best },
                      others: suspects.filter { $0.matched < best })
    }

    /// The germ's telltale sign, else its first sign that is not ticked yet.
    static func clue(for germ: Germ, chosen: Set<String>) -> SuspectClue? {
        if let sign = germ.symptoms.first(where: { $0.telltale == true }) {
            return SuspectClue(isTelltale: true, text: lowercasedStart(sign.text.value))
        }
        let fresh = germ.symptoms.first { Set($0.tags ?? []).isDisjoint(with: chosen) }
        return fresh.map { SuspectClue(isTelltale: false, text: lowercasedStart($0.text.value)) }
    }

    private static func lowercasedStart(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }
}
