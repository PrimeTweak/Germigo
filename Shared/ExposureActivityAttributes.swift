import ActivityKit
import Foundation

/// Live Activity that follows the incubation window after a kid gets sick.
struct ExposureActivityAttributes: ActivityAttributes {
    /// The countdown is driven by the dates below, so no state changes over time.
    struct ContentState: Codable, Hashable {}

    var exposureID: String
    var kidName: String
    var germID: String
    var germName: String
    var illness: String
    var exposedAt: Date
    var windowOpens: Date
    var windowCloses: Date
}
