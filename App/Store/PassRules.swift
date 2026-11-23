import Foundation

/// Why someone is looking at the Season Pass: the door they touched. The offer leads with it.
enum PassReason: String, Identifiable, CaseIterable {
    case general
    case household
    case history
    case photos
    case doctor
    case stats
    case crew
    case looks
    case characters
    case holo

    var id: String { rawValue }

    /// The offer's headline: what this door gives.
    var headline: String {
        switch self {
        case .general: tr("Every kid, every week, every photo.")
        case .household: tr("Bring the whole household.")
        case .history: tr("Keep every week.")
        case .photos: tr("Keep the photos.")
        case .doctor: tr("Hand the doctor a clean file.")
        case .stats: tr("See who brings the most home.")
        case .crew: tr("Know what's going around.")
        case .looks: tr("Make Germily yours.")
        case .characters: tr("Pick from every character.")
        case .holo: tr("Turn your cards holo.")
        }
    }

    /// One line under the headline.
    var detail: String {
        switch self {
        case .general: tr("The Season Pass opens Germily for the whole household, all season.")
        case .household: tr("Every kid, your partner and the couple duel.")
        case .history: tr("The free journal shows the last 7 days. The Pass keeps the whole season.")
        case .photos: tr("Rashes, thermometers, daycare notes: filed by illness, ready to show.")
        case .doctor: tr("Dates, signs and photos of the last 6 months, in one PDF.")
        case .stats: tr("The family league, your top supplier and the season in numbers.")
        case .crew: tr("Daycare Crew is an outbreak radar for your group.")
        case .looks: tr("Every theme, every icon and the incubation widget.")
        case .characters: tr("%lld more characters for the family, each with its own sick face.", Looks.count - Looks.free.count)
        case .holo: tr("Catch a germ three times and its card goes holo.")
        }
    }

    /// What a lock says it opens, in a few words.
    var gain: String {
        switch self {
        case .general: tr("The whole Season Pass")
        case .household: tr("Every kid and your partner")
        case .history: tr("Every week, kept")
        case .photos: tr("Photos, kept by illness")
        case .doctor: tr("A PDF for the doctor")
        case .stats: tr("Your season in numbers")
        case .crew: tr("The outbreak radar")
        case .looks: tr("Every theme and icon")
        case .characters: tr("Every character")
        case .holo: tr("Holo cards")
        }
    }
}

/// The steps of a free trial, for the offer and for the reminder before the first payment.
struct TrialPlan: Equatable {
    /// How many days before the first payment the reminder goes out.
    static let notice = 2

    let days: Int

    /// The day the reminder goes out, counted from the start; nil when the trial is too short for one.
    var reminderDay: Int? {
        days > Self.notice + 1 ? days - Self.notice : nil
    }

    /// When to remind, from the end of the trial; nil once that moment has passed.
    static func reminderDate(endsAt: Date, now: Date) -> Date? {
        let date = endsAt.addingTimeInterval(-Double(notice) * 86_400)
        return date > now ? date : nil
    }
}
