import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The incubation watch on the Lock Screen and in the Dynamic Island.
struct ExposureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExposureActivityAttributes.self) { context in
            ExposureLockScreenView(attributes: context.attributes, isClosed: context.isStale)
                .activityBackgroundTint(WidgetInk.ground)
                .activitySystemActionForegroundColor(WidgetInk.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("germ-" + context.attributes.germID)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.windowCloses, style: .relative)
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(tr("%@ watch", context.attributes.germName))
                            .font(.system(size: 15, weight: .bold))
                        Text(context.attributes.kidName + " · " + context.attributes.illness)
                            .font(.system(size: 12))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExposureButtons(exposureID: context.attributes.exposureID)
                }
            } compactLeading: {
                Image("germ-" + context.attributes.germID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                Image(systemName: "hourglass")
                    .foregroundStyle(WidgetInk.ink)
            } minimal: {
                Image("germ-" + context.attributes.germID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .keylineTint(WidgetInk.accent)
        }
    }
}

private struct ExposureLockScreenView: View {
    let attributes: ExposureActivityAttributes
    let isClosed: Bool

    private var lowHours: Int {
        Int(attributes.windowOpens.timeIntervalSince(attributes.exposedAt) / 3600)
    }

    private var highHours: Int {
        Int(attributes.windowCloses.timeIntervalSince(attributes.exposedAt) / 3600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image("germ-" + attributes.germID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("%@ watch", attributes.germName))
                        .font(.system(size: 17, weight: .bold))
                    Text(attributes.kidName + " · " + attributes.illness)
                        .font(.system(size: 13))
                        .opacity(0.7)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isClosed {
                    Text(tr("Window passed"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WidgetInk.accent)
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(attributes.windowCloses, style: .relative)
                            .font(.system(size: 17, weight: .bold))
                            .multilineTextAlignment(.trailing)
                        Text(tr("left in window"))
                            .font(.system(size: 11))
                            .opacity(0.7)
                    }
                    .frame(maxWidth: 120, alignment: .trailing)
                }
            }
            if !isClosed {
                ProgressView(timerInterval: attributes.exposedAt...max(attributes.windowCloses, attributes.exposedAt.addingTimeInterval(60)),
                             countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(WidgetInk.accent)
            }
            Text(isClosed ? tr("The usual window has passed. Did you dodge it?")
                          : tr("Symptoms usually show %1$lld to %2$lld h after exposure.", lowHours, highHours))
                .font(.system(size: 12))
                .opacity(0.7)
            ExposureButtons(exposureID: attributes.exposureID)
        }
        .foregroundStyle(WidgetInk.ink)
        .padding(16)
    }
}

private struct ExposureButtons: View {
    let exposureID: String

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: CaughtItIntent(exposureID: exposureID)) {
                Label(tr("It got me"), systemImage: "thermometer.medium")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .tint(WidgetInk.accent)
            Button(intent: StillFineIntent(exposureID: exposureID)) {
                Label(tr("Still fine"), systemImage: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .tint(WidgetInk.ink.opacity(0.25))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }
}
