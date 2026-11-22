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
}

/// The online lesson file.
struct LessonFeed: Codable {
    let lessons: [FeedLesson]
}

/// When lessons come out and open: open to everyone for their first week, then by right answers.
enum LessonEngine {
    /// Right answers between two steps of the ladder.
    static let step = 5
    /// Days a new lesson stays open to everyone.
    static let openDays = 7
    /// Least time between two checks of the online lesson file.
    static let checkGap: TimeInterval = 3600

    /// True when the online file has not been checked within the gap, or the clock went back.
    static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= checkGap || now < lastCheck
    }

    /// Midnight of the release day in the phone's time zone.
    static func releaseDay(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The bundled articles, then the online ones in release order, each one step above the last.
    static func merge(bundled: [Article], feed: [FeedLesson], calendar: Calendar = .current) -> [Article] {
        var seen = Set(bundled.map { $0.id })
        var top = bundled.map { $0.unlockAtAnswers }.max() ?? 0
        let dated = feed.compactMap { lesson -> (lesson: FeedLesson, day: Date)? in
            guard let day = releaseDay(lesson.released, calendar: calendar) else { return nil }
            return (lesson, day)
        }
        .sorted { ($0.day, $0.lesson.id) < ($1.day, $1.lesson.id) }
        var merged = bundled
        for item in dated {
            guard seen.insert(item.lesson.id).inserted else { continue }
            top += step
            let lesson = item.lesson
            merged.append(Article(id: lesson.id, icon: lesson.icon ?? "graduationcap", unlockAtAnswers: top,
                                  title: lesson.title, summary: lesson.summary, paragraphs: lesson.paragraphs,
                                  sources: lesson.sources, releasedOn: item.day))
        }
        return merged
    }

    static func isReleased(_ article: Article, now: Date) -> Bool {
        guard let day = article.releasedOn else { return true }
        return now >= day
    }

    static func isOpenToAll(_ article: Article, now: Date, calendar: Calendar = .current) -> Bool {
        guard let day = article.releasedOn, now >= day,
              let end = calendar.date(byAdding: .day, value: openDays, to: day) else { return false }
        return now < end
    }

    /// Days left in the open week, today included.
    static func daysLeft(_ article: Article, now: Date, calendar: Calendar = .current) -> Int {
        guard let day = article.releasedOn else { return 0 }
        let passed = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, openDays - passed)
    }

    /// A lesson read once stays open.
    static func isUnlocked(_ article: Article, data: AppData, now: Date) -> Bool {
        data.readArticles.contains(article.id) || isOpenToAll(article, now: now)
            || data.quiz.rightTotal >= article.unlockAtAnswers
    }

    /// The lessons in reading order: this week's unread ones, the other open unread ones,
    /// the locked ones by step, then those already read.
    static func readingOrder(_ articles: [Article], data: AppData, now: Date) -> [Article] {
        func rank(_ article: Article) -> Int {
            if data.readArticles.contains(article.id) { return 3 }
            if isOpenToAll(article, now: now) { return 0 }
            return isUnlocked(article, data: data, now: now) ? 1 : 2
        }
        return articles.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map { $0.element }
    }
}
