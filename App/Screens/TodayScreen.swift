import SwiftUI

/// The home: one character, one number or headline, and two answers.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showKidSheet = false
    @State private var exposurePage = 0

    private var mascotTint: Color { Color(hex: Swatch.irisSoft) }

    var body: some View {
        let exposures = model.openExposures
        let index = min(max(0, exposurePage), max(0, exposures.count - 1))
        NavigationStack {
            GeometryReader { proxy in
                let side = min(236, max(132, proxy.size.height * 0.3))
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(palette.ink.opacity(0.8))
                        .padding(.horizontal, 4)
                    if let log = model.activeLog, let germ = model.activeGerm {
                        SickStage(log: log, germ: germ, side: side)
                    } else if index < exposures.count, let germ = model.catalog.germ(exposures[index].germID) {
                        ExposureStage(illness: exposures[index], germ: germ, side: side, page: $exposurePage,
                                      pages: exposures.count)
                            .id(exposures[index].id)
                    } else {
                        CalmStage(side: side, showKidSheet: $showKidSheet)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(CharacterWash(tint: washTint(exposures: exposures, index: index)))
            .navigationTitle(tr("Today"))
            .toolbar {
                if model.activeLog != nil || !exposures.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showKidSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(tr("Add a kid's germ"))
                    }
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .sheet(isPresented: $showKidSheet) {
                KidIllnessSheet()
            }
        }
    }

    private func washTint(exposures: [KidIllness], index: Int) -> Color {
        if let germ = model.activeGerm { return germ.deepTint }
        if index < exposures.count, let germ = model.catalog.germ(exposures[index].germID) { return germ.deepTint }
        return mascotTint
    }
}

/// The lines under the character: a quiet lead, the headline, and what follows.
private struct StageText: View {
    let lead: String
    let headline: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            Text(lead)
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
            Text(headline)
                .font(.title.weight(.bold))
                .foregroundStyle(palette.ink)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
    }
}

/// Nobody is sick: the mascot sleeps on the counter.
private struct CalmStage: View {
    let side: CGFloat
    @Binding var showKidSheet: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var awakeUntil = Date.distantPast

    var body: some View {
        let days = model.streakDays()
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            mascot
            Text(tr("This household has gone"))
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 12)
            Text(verbatim: String(days))
                .font(.system(size: side > 200 ? 112 : 84, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: days)
            Text(trCount(days, one: "day without a germ", other: "days without a germ"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                FaceTile(tr("A kid is sick")) {
                    showKidSheet = true
                } face: {
                    kidFace
                }
                FaceTile(tr("I'm sick")) {
                    model.logRequest = LogRequest()
                } face: {
                    Image("mascot-awake").resizable().scaledToFit()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var mascot: some View {
        LivelyCharacter(mood: .asleep) {
            TimelineView(.periodic(from: Date(), by: 0.5)) { timeline in
                Image(timeline.date < awakeUntil ? "mascot-awake" : "mascot-asleep")
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        if timeline.date >= awakeUntil {
                            SnoreView()
                                .offset(x: 34, y: -6)
                        }
                    }
            }
        }
        .frame(width: side, height: side)
        .simultaneousGesture(TapGesture().onEnded { _ in
            awakeUntil = Date().addingTimeInterval(reduceMotion ? 4 : 2.4)
        })
        .accessibilityLabel(tr("The germs are napping."))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var kidFace: some View {
        if let kid = model.data.kids.first {
            AvatarView(name: kid.name, gradient: AvatarColors.gradient(kid.colorIndex), size: 62)
        } else {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 62, height: 62)
                .background(palette.ink.opacity(0.07), in: Circle())
        }
    }
}

/// A kid is sick: the germ is after the parent until the usual window has passed.
private struct ExposureStage: View {
    let illness: KidIllness
    let germ: Germ
    let side: CGFloat
    @Binding var page: Int
    let pages: Int
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var askStillFine = false
    @State private var showCaseFile = false
    @State private var protecting: KidIllness?

    private var window: (opens: Date, closes: Date)? { germ.window(from: illness.startedAt) }
    private var hasPassed: Bool { window.map { Date() > $0.closes } ?? false }

    var body: some View {
        let kidName = model.kid(illness.kidID)?.name ?? tr("Your kid")
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LivelyCharacter(mood: .stalking) {
                GermImage(germ: germ, size: side)
            }
            StageText(lead: tr("%1$@ brought home %2$@", kidName, germ.phrase.value),
                      headline: tr("%@ is after you", germ.name), detail: detail)
                .padding(.top, 14)
            if pages > 1 {
                Button {
                    withAnimation(.snappy) {
                        page = (page + 1) % pages
                    }
                } label: {
                    Text(tr("%1$lld of %2$lld", min(page, pages - 1) + 1, pages))
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(palette.ink.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint(tr("Next"))
                .padding(.top, 12)
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                FaceTile(hasPassed ? tr("Dodged it") : tr("Still fine")) {
                    if hasPassed {
                        dodge()
                    } else {
                        askStillFine = true
                    }
                } face: {
                    Image("mascot-asleep").resizable().scaledToFit()
                }
                FaceTile(tr("It got me")) {
                    model.logRequest = LogRequest(kidIllnessID: illness.id)
                } face: {
                    GermImage(germ: germ, size: 62)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .confirmationDialog(tr("Still fine. What now?"), isPresented: $askStillFine, titleVisibility: .visible) {
            Button(tr("Protect the rest of the house")) {
                protecting = illness
            }
            if window != nil {
                Button(illness.watching ? tr("Stop the reminders") : tr("Remind me when the window opens")) {
                    toggleWatch()
                }
            }
            Button(tr("Case file")) {
                showCaseFile = true
            }
            Button(tr("Call it dodged")) {
                dodge()
            }
            Button(tr("Cancel"), role: .cancel) {}
        }
        .navigationDestination(isPresented: $showCaseFile) {
            GermDetailScreen(germ: germ)
        }
        .sheet(item: $protecting) { illness in
            NavigationStack {
                ProtectHomeView(illness: illness) {
                    protecting = nil
                }
            }
        }
    }

    /// Where the countdown stands, then what is at stake.
    private var detail: String {
        guard let window = window else {
            return tr("No countdown for this one. The case file explains what to watch for.")
        }
        let now = Date()
        if now > window.closes {
            return tr("The usual window has passed. Did you dodge it?")
        }
        let closes = window.closes.formatted(.dateTime.weekday(.wide))
        let status = now < window.opens
            ? tr("Dodge it from %1$@ to %2$@.", window.opens.formatted(.dateTime.weekday(.wide)), closes)
            : tr("You're in the window until %@.", closes)
        let streak = model.streakDays()
        guard streak > 0 else { return status }
        return status + " " + trCount(streak, one: "%lld day without a germ is on the line.",
                                      other: "%lld days without a germ are on the line.")
    }

    private func dodge() {
        Haptics.success()
        model.resolveExposure(illness.id, outcome: .dodged)
    }

    private func toggleWatch() {
        if illness.watching {
            model.setWatching(illness.id, watching: false)
            return
        }
        Task {
            _ = await NotificationManager.requestAuthorization()
            model.setWatching(illness.id, watching: true)
        }
    }
}

/// The parent is sick: the germ has a life bar that drains with each day of its usual length.
private struct SickStage: View {
    let log: SickLog
    let germ: Germ
    let side: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showKit = false

    /// A hard hit drops the fight talk, like the reward screen does.
    private var gentle: Bool { log.severity >= 5 }

    var body: some View {
        let day = log.dayCount()
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LivelyCharacter(mood: .sick) {
                GermImage(germ: germ, size: side)
            }
            StageText(lead: lead(day: day), headline: headline(day: day))
                .padding(.top, 14)
            if let left = lifeLeft(day: day) {
                ThinGauge(fraction: left)
                    .frame(width: 240)
                    .padding(.top, 14)
            }
            Text(detail(day: day))
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                FaceTile(tr("Still sick")) {
                    showKit = true
                } face: {
                    GermImage(germ: germ, size: 62)
                }
                FaceTile(tr("I'm better")) {
                    model.askBetter = true
                } face: {
                    Image("mascot-awake").resizable().scaledToFit()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showKit) {
            SickKitSheet(log: log, germ: germ)
        }
    }

    private func isOverdue(day: Int) -> Bool {
        germ.lastsUpToDays.map { day > $0 } ?? false
    }

    /// The share of the germ's usual length still ahead; none when gentle, overdue or unknown.
    private func lifeLeft(day: Int) -> Double? {
        guard !gentle, !isOverdue(day: day), let upTo = germ.lastsUpToDays, upTo > 0 else { return nil }
        return 1 - Double(day) / Double(upTo)
    }

    private func lead(day: Int) -> String {
        guard !gentle, !isOverdue(day: day) else { return tr("Day %lld", day) }
        if let upTo = germ.lastsUpToDays { return tr("Round %1$lld of up to %2$lld", day, upTo) }
        return tr("Round %lld", day)
    }

    private func headline(day: Int) -> String {
        if gentle || isOverdue(day: day) { return germ.illness.value }
        if let left = lifeLeft(day: day) {
            return tr("%1$@ is at %2$lld%%", germ.name, Int((left * 100).rounded()))
        }
        return tr("%@ has you", germ.name)
    }

    private func detail(day: Int) -> String {
        var text: String
        if isOverdue(day: day) {
            text = tr("Longer than usual. Check when to call in the case file.")
        } else if gentle {
            text = tr("Rest. The case file says when to call.")
        } else {
            text = tr("Outlast it. Its bar drains a little every day.")
        }
        if log.sufferer != .me {
            text += " " + tr("Sick: %@", model.name(of: log.sufferer))
        }
        return text
    }
}

/// What "Still sick" opens: today's advice, the case file and the nap coupon.
private struct SickKitSheet: View {
    let log: SickLog
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showCoupon = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: tr("Next 48 hours"))
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(germ.tips.enumerated()), id: \.offset) { item in
                            if item.offset > 0 {
                                Divider()
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.title.value)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                Text(item.element.body.value)
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .petriCard(padding: 0)
                    NavigationLink {
                        GermDetailScreen(germ: germ)
                    } label: {
                        ValueRow(title: tr("Case file and when to call"))
                            .padding(.horizontal, 16)
                            .petriCard(padding: 0)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showCoupon = true
                    } label: {
                        Label(tr("Nap coupon"), systemImage: "ticket")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                    Text(HealthNotice.text)
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("%1$@ · Day %2$lld", germ.illness.value, log.dayCount()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Done"))
                }
            }
            .sheet(isPresented: $showCoupon) {
                SharePreviewSheet(title: tr("Nap coupon")) {
                    if log.sufferer == .partner {
                        NapCouponCard(from: model.partnerDisplayName, to: model.displayName, germ: germ)
                    } else {
                        NapCouponCard(from: model.displayName, to: model.data.partnerName, germ: germ)
                    }
                }
            }
        }
    }
}
