import Foundation

/// Where a germ's activity went since the report before.
enum GoingAroundTrend: String, Codable, Hashable {
    case rising
    case steady
    case falling
    case low
}

/// One germ in a report, with a line in our words.
struct GoingAroundGerm: Codable, Hashable {
    let germID: String
    let trend: GoingAroundTrend
    let line: LocalizedText
}

/// A public health report for one country, summarized in our words.
struct GoingAroundReport: Codable, Hashable, Identifiable {
    let id: String
    /// `CA` or `US`.
    let region: String
    /// The first day of the week the report covers, written `yyyy-MM-dd`.
    let week: String
    /// The day the source published it, written `yyyy-MM-dd`.
    let published: String
    let headline: LocalizedText
    let germs: [GoingAroundGerm]
    let source: GermReference
    /// The day the summary was approved, written `yyyy-MM-dd`; the server serves no report without one.
    let approvedOn: String?
}

/// Which report the Guide shows.
enum GoingAroundEngine {
    /// A report published longer ago than this is not shown: summer reports come once a month.
    static let freshDays = 35
    static let regions = ["CA", "US"]

    /// The phone's country when it has reports; nil elsewhere, where none is shown.
    static func region(for code: String?) -> String? {
        code.flatMap { regions.contains($0) ? $0 : nil }
    }

    /// The region's newest report published within the fresh window, with only the germs the app knows.
    static func current(_ reports: [GoingAroundReport], region: String, known: Set<String>, now: Date,
                        calendar: Calendar = .current) -> GoingAroundReport? {
        let today = calendar.startOfDay(for: now)
        let latest = reports
            .filter { $0.region == region }
            .compactMap { report -> (report: GoingAroundReport, day: Date)? in
                guard let day = LessonEngine.calendarDay(report.published, calendar: calendar), day <= today,
                      let age = calendar.dateComponents([.day], from: day, to: today).day, age < freshDays else { return nil }
                return (report, day)
            }
            .max { ($0.day, $0.report.id) < ($1.day, $1.report.id) }?.report
        guard let latest else { return nil }
        let germs = latest.germs.filter { known.contains($0.germID) }
        guard !germs.isEmpty else { return nil }
        return GoingAroundReport(id: latest.id, region: latest.region, week: latest.week, published: latest.published,
                                 headline: latest.headline, germs: germs, source: latest.source, approvedOn: latest.approvedOn)
    }
}
