import Foundation

/// One person sick on one day, and with what.
struct DayEntry: Identifiable, Hashable {
    let person: Person
    let germID: String
    let symptoms: [String]
    /// The day of the illness, the first one being day one.
    let dayNumber: Int
    /// How many days it lasted once over; nil while it goes on or when its end is only assumed.
    let length: Int?
    let logID: UUID?
    let illnessID: UUID?
    /// True on the day a kid was marked better.
    let isLastDay: Bool

    var id: String {
        let source = (logID ?? illnessID)?.uuidString ?? germID
        switch person {
        case .me: return "me-" + source
        case .partner: return "partner-" + source
        case .kid(let kidID): return kidID.uuidString + "-" + source
        }
    }
}

/// A day's photos: on the card of the illness they belong to, else on the person's first card, else apart.
struct DayPhotos {
    var byEntry: [String: [PatientPhoto]] = [:]
    var others: [PatientPhoto] = []
}

/// Who was sick on which day, for the week on Today and the day pages.
enum DayEngine {
    /// How long a kid's illness counts when nobody said it ended and its germ has no usual length.
    static let defaultKidDays = 7

    /// When a kid's illness ends: the day it was marked over, or else its germ's usual length, never after now.
    static func kidEnd(_ illness: KidIllness, catalog: GermCatalog, now: Date) -> Date {
        if let end = illness.endedAt { return end }
        let days = max(1, catalog.germ(illness.germID)?.lastsUpToDays ?? defaultKidDays)
        let assumed = Calendar.current.date(byAdding: .day, value: days - 1, to: illness.startedAt) ?? illness.startedAt
        return min(now, assumed)
    }

    /// True while nobody said the kid is better and the illness still covers today.
    static func isGoingOn(_ illness: KidIllness, catalog: GermCatalog, now: Date) -> Bool {
        guard illness.endedAt == nil else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: kidEnd(illness, catalog: catalog, now: now)) >= calendar.startOfDay(for: now)
    }

    /// The first day worth opening: install day, or the oldest entry when it was dated earlier.
    static func firstDay(data: AppData) -> Date {
        let starts = data.logs.map { $0.startedAt } + data.kidIllnesses.map { $0.startedAt }
        return Calendar.current.startOfDay(for: min(data.installedAt, starts.min() ?? data.installedAt))
    }

    /// Everyone sick on a day: the parent, the partner, then the kids in the household's order.
    static func entries(on day: Date, data: AppData, catalog: GermCatalog, now: Date) -> [DayEntry] {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: day)
        guard target <= calendar.startOfDay(for: now) else { return [] }
        var mine: [DayEntry] = []
        var partner: [DayEntry] = []
        for log in data.logs.sorted(by: { $0.startedAt < $1.startedAt }) {
            let start = calendar.startOfDay(for: log.startedAt)
            guard start <= target, target <= calendar.startOfDay(for: log.endedAt ?? now) else { continue }
            let number = StreakMath.days(from: start, to: target) + 1
            let length = log.endedAt == nil ? nil : log.dayCount(now: now)
            for person in [Person.me, .partner] {
                guard person == .me ? log.sufferer.includesMe : log.sufferer.includesPartner else { continue }
                let entry = DayEntry(person: person, germID: log.germID, symptoms: log.symptoms, dayNumber: number,
                                     length: length, logID: log.id, illnessID: nil, isLastDay: false)
                if person == .me { mine.append(entry) } else { partner.append(entry) }
            }
        }
        let order = Dictionary(data.kids.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let illnesses = data.kidIllnesses.sorted {
            (order[$0.kidID] ?? Int.max, $0.startedAt) < (order[$1.kidID] ?? Int.max, $1.startedAt)
        }
        var kids: [DayEntry] = []
        for illness in illnesses {
            let start = calendar.startOfDay(for: illness.startedAt)
            let end = calendar.startOfDay(for: kidEnd(illness, catalog: catalog, now: now))
            guard start <= target, target <= end else { continue }
            let ended = illness.endedAt != nil
            kids.append(DayEntry(person: .kid(illness.kidID), germID: illness.germID, symptoms: illness.symptoms,
                                 dayNumber: StreakMath.days(from: start, to: target) + 1,
                                 length: ended ? StreakMath.days(from: start, to: end) + 1 : nil,
                                 logID: nil, illnessID: illness.id, isLastDay: ended && target == end))
        }
        return mine + partner + kids
    }

    /// Spreads the photos taken on a day over that day's cards.
    static func photos(on day: Date, entries: [DayEntry], data: AppData) -> DayPhotos {
        let calendar = Calendar.current
        var result = DayPhotos()
        let taken = data.photos.filter { calendar.isDate($0.takenAt, inSameDayAs: day) }.sorted { $0.takenAt < $1.takenAt }
        for photo in taken {
            let linked = entries.first { entry in
                entry.person == photo.person
                    && ((photo.logID != nil && photo.logID == entry.logID)
                        || (photo.illnessID != nil && photo.illnessID == entry.illnessID))
            }
            if let entry = linked ?? entries.first(where: { $0.person == photo.person }) {
                result.byEntry[entry.id, default: []].append(photo)
            } else {
                result.others.append(photo)
            }
        }
        return result
    }
}
