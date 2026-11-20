import Foundation

/// Invariants of the journal, applied after every change to the logs.
enum JournalRules {
    /// Only the most recent log may stay open: an earlier open log ends when the next one starts,
    /// and no log ends before it starts. The stored order is kept.
    static func normalized(_ logs: [SickLog]) -> [SickLog] {
        var result = logs
        let order = result.indices.sorted { result[$0].startedAt < result[$1].startedAt }
        for (position, index) in order.enumerated() {
            if let end = result[index].endedAt, end < result[index].startedAt {
                result[index].endedAt = result[index].startedAt
            }
            guard result[index].endedAt == nil, position + 1 < order.count else { continue }
            let next = result[order[position + 1]].startedAt
            result[index].endedAt = max(result[index].startedAt, next)
        }
        return result
    }

    /// The log that may still be open: the one that started last.
    static func latestID(in logs: [SickLog]) -> UUID? {
        logs.max { $0.startedAt < $1.startedAt }?.id
    }
}
