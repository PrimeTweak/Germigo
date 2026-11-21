import SwiftUI
import WidgetKit

/// The countdown after a kid gets sick. Part of the Season Pass.
struct IncubationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IncubationWidget", provider: SnapshotProvider()) { entry in
            IncubationWidgetView(entry: entry)
        }
        .configurationDisplayName(tr("Incubation watch"))
        .description(tr("Counts down your window after a kid gets sick."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Where a moment sits relative to the incubation window.
enum WindowPhase {
    case before
    case inside
    case after

    init(opens: Date, closes: Date, now: Date) {
        if now < opens {
            self = .before
        } else if now <= closes {
            self = .inside
        } else {
            self = .after
        }
    }
}

struct IncubationWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        content
            .foregroundStyle(WidgetInk.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { WidgetInk.ground }
    }

    @ViewBuilder
    private var content: some View {
        if !entry.snapshot.hasPass {
            message(symbol: "ticket.fill", title: tr("Season Pass"), detail: tr("The incubation watch comes with the Pass."))
        } else if let exposure = entry.snapshot.exposure {
            watch(exposure)
        } else {
            message(symbol: "checkmark.seal.fill", title: tr("All clear"), detail: tr("No kid is sick right now. Enjoy it."))
        }
    }

    private func message(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(WidgetInk.accent)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(detail)
                .font(.system(size: 12))
                .opacity(0.65)
                .lineLimit(3)
        }
    }

    private func watch(_ exposure: WidgetSnapshot.Exposure) -> some View {
        let phase = WindowPhase(opens: exposure.windowOpens, closes: exposure.windowCloses, now: entry.date)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image("germ-" + exposure.germID)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(exposure.kidName)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text(exposure.illness)
                        .font(.system(size: 11))
                        .opacity(0.65)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            switch phase {
            case .before:
                Text(tr("Window opens"))
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.65)
                Text(exposure.windowOpens, style: .relative)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WidgetInk.ink)
                    .widgetAccentable()
            case .inside:
                Text(tr("In the window"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetInk.accent)
                Text(exposure.windowCloses, style: .relative)
                    .font(.system(size: 18, weight: .bold))
                    .widgetAccentable()
            case .after:
                Text(tr("Window passed"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetInk.accent)
                    .widgetAccentable()
                Text(tr("Did you dodge it?"))
                    .font(.system(size: 11))
                    .opacity(0.65)
            }
            if phase != .after {
                ProgressView(timerInterval: exposure.exposedAt...max(exposure.windowCloses, exposure.exposedAt.addingTimeInterval(60)),
                             countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(WidgetInk.accent)
            }
        }
    }
}
