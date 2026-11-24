import Foundation

/// A lesson from the online file: an article with its release day and no ladder step yet.
struct FeedLesson: Codable, Hashable {
    let id: String
    let icon: String?
    /// The release day, written `yyyy-MM-dd`.
    let released: String
    let title: LocalizedText
    let summary: LocalizedText
    let paragraphs: [LocalizedText]
    let sources: [GermReference]
    /// The day a health professional approved it, written `yyyy-MM-dd`; the server serves no lesson without one.
    let reviewedOn: String?
}

/// The online Guide file: the lessons, and the weekly "Going around" reports.
struct LessonFeed: Codable {
    let lessons: [FeedLesson]
    let goingAround: [GoingAroundReport]?

    static let empty = LessonFeed(lessons: [], goingAround: nil)
}

/// When lessons come out and open: a bundled lesson with right answers in the daily quiz,
/// an online lesson with the Season Pass.
enum LessonEngine {
    /// Right answers between two steps of the ladder.
    static let step = 5
    /// Days a lesson counts as new.
    static let newDays = 7
    /// Least time between two checks of the online lesson file.
    static let checkGap: TimeInterval = 3600

    /// True when the online file has not been checked within the gap, or the clock went back.
    static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= checkGap || now < lastCheck
    }

    /// Midnight of a day written `yyyy-MM-dd`, in the phone's time zone.
    static func calendarDay(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The bundled lessons up their ladder, then the online ones in release order.
    static func merge(bundled: [Article], feed: [FeedLesson], calendar: Calendar = .current) -> [Article] {
        var seen = Set(bundled.map { $0.id })
        let dated = feed.compactMap { lesson -> (lesson: FeedLesson, day: Date)? in
            guard let day = calendarDay(lesson.released, calendar: calendar) else { return nil }
            return (lesson, day)
        }
        .sorted { ($0.day, $0.lesson.id) < ($1.day, $1.lesson.id) }
        var merged = bundled.sorted { $0.unlockAtAnswers < $1.unlockAtAnswers }
        for item in dated {
            guard seen.insert(item.lesson.id).inserted else { continue }
            let lesson = item.lesson
            merged.append(Article(id: lesson.id, icon: lesson.icon ?? "graduationcap", unlockAtAnswers: 0,
                                  title: lesson.title, summary: lesson.summary, paragraphs: lesson.paragraphs,
                                  sources: lesson.sources, releasedOn: item.day, reviewedOn: lesson.reviewedOn))
        }
        return merged
    }

    static func isReleased(_ article: Article, now: Date) -> Bool {
        guard let day = article.releasedOn else { return true }
        return now >= day
    }

    /// An online lesson in its first week.
    static func isNew(_ article: Article, now: Date, calendar: Calendar = .current) -> Bool {
        guard let day = article.releasedOn, now >= day,
              let end = calendar.date(byAdding: .day, value: newDays, to: day) else { return false }
        return now < end
    }

    /// A lesson read once stays open.
    static func isUnlocked(_ article: Article, data: AppData, hasPass: Bool) -> Bool {
        if data.readArticles.contains(article.id) { return true }
        return article.needsPass ? hasPass : data.quiz.rightTotal >= article.unlockAtAnswers
    }

    /// The lessons in reading order: this week's open unread ones, the other open unread ones,
    /// the locked ones, then those already read.
    static func readingOrder(_ articles: [Article], data: AppData, hasPass: Bool, now: Date) -> [Article] {
        func rank(_ article: Article) -> Int {
            if data.readArticles.contains(article.id) { return 3 }
            guard isUnlocked(article, data: data, hasPass: hasPass) else { return 2 }
            return isNew(article, now: now) ? 0 : 1
        }
        return articles.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map { $0.element }
    }
}
