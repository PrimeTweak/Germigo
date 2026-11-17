import SwiftUI
import WidgetKit

/// The "days without a germ" sign, for the Home Screen and the Lock Screen.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: SnapshotProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName(tr("Days without a germ"))
        .description(tr("Your household's current run."))
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var isSick: Bool { entry.snapshot.sickGermID != nil }
    private var days: Int { isSick ? 0 : entry.snapshot.streakDays(at: entry.date) }
    private var caption: String {
        trCount(days, one: "day without a germ", other: "days without a germ")
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(trCount(days, one: "%lld day without a germ", other: "%lld days without a germ"))
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            VStack(spacing: -2) {
                Text(String(days))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(trCount(days, one: "day", other: "days"))
                    .font(.system(size: 9, weight: .semibold))
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Text(String(days))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    if isSick, let illness = entry.snapshot.sickIllness {
                        Text(illness)
                            .font(.system(size: 11))
                            .opacity(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            small
                .containerBackground(for: .widget) { WidgetInk.night }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Capsule()
                    .fill(isSick ? WidgetInk.coral : WidgetInk.hazard)
                    .frame(width: 18, height: 6)
                Text(verbatim: "PETRI")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(1.4)
                    .opacity(0.6)
            }
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(days))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(isSick ? WidgetInk.coral : WidgetInk.lime)
                    .widgetAccentable()
                if isSick, let id = entry.snapshot.sickGermID {
                    Image("germ-" + id)
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                }
            }
            Text(caption)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(isSick ? (entry.snapshot.sickIllness ?? "") : tr("Record: %lld", entry.snapshot.recordDays))
                .font(.system(size: 11, weight: .medium))
                .opacity(0.55)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .foregroundStyle(WidgetInk.chalk)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
