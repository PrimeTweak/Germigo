import SwiftUI

/// One density of Today. The screen shows the richest one that fits, so the page does not scroll.
private struct TodayFit {
    enum Sign {
        case tile(CGFloat)
        case strip
        case hidden
    }

    enum Rows {
        case full
        case short
        case quizOnly
        case hidden
    }

    var sign: Sign
    var compact = false
    var tips = 2
    var progress = Rows.full

    /// Six densities from richest to leanest, then the one used when even the leanest has to scroll.
    static func candidates(sick: Bool, incoming: Bool) -> [TodayFit] {
        if sick {
            return [
                TodayFit(sign: .strip, progress: .short),
                TodayFit(sign: .strip, progress: .quizOnly),
                TodayFit(sign: .hidden, progress: .quizOnly),
                TodayFit(sign: .hidden, compact: true, progress: .quizOnly),
                TodayFit(sign: .hidden, compact: true, tips: 1, progress: .quizOnly),
                TodayFit(sign: .hidden, compact: true, tips: 1, progress: .hidden),
                TodayFit(sign: .strip, progress: .short)
            ]
        }
        if incoming {
            return [
                TodayFit(sign: .strip),
                TodayFit(sign: .strip, compact: true),
                TodayFit(sign: .strip, compact: true, progress: .short),
                TodayFit(sign: .strip, compact: true, progress: .quizOnly),
                TodayFit(sign: .hidden, compact: true, progress: .quizOnly),
                TodayFit(sign: .hidden, compact: true, progress: .hidden),
                TodayFit(sign: .strip)
            ]
        }
        return [
            TodayFit(sign: .tile(92)),
            TodayFit(sign: .tile(78)),
            TodayFit(sign: .tile(66)),
            TodayFit(sign: .tile(56)),
            TodayFit(sign: .tile(56), progress: .short),
            TodayFit(sign: .strip, progress: .short),
            TodayFit(sign: .tile(66))
        ]
    }
}

struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showSettings = false
    @State private var showKidSheet = false
    @State private var showQuiz = false
    @State private var showCoupon = false
    @State private var exposurePage = 0

    var body: some View {
        let fits = TodayFit.candidates(sick: model.activeLog != nil, incoming: !model.openExposures.isEmpty)
        NavigationStack {
            ViewThatFits(in: .vertical) {
                page(fits[0])
                page(fits[1])
                page(fits[2])
                page(fits[3])
                page(fits[4])
                page(fits[5])
                ScrollView {
                    page(fits[6])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Today"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(tr("Settings"))
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .sheet(isPresented: $showSettings) {
                SettingsScreen()
            }
            .sheet(isPresented: $showKidSheet) {
                KidIllnessSheet()
            }
            .sheet(isPresented: $showCoupon) {
                couponSheet
            }
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
        }
    }

    @ViewBuilder
    private func page(_ fit: TodayFit) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
            sign(fit.sign)
            if let log = model.activeLog, let germ = model.activeGerm {
                SickNowCard(log: log, germ: germ, compact: fit.compact, showCoupon: $showCoupon)
                TipsCard(germ: germ, day: log.dayCount(), count: fit.tips)
            } else {
                HoldToLogButton {
                    model.logRequest = LogRequest()
                }
                if model.openExposures.isEmpty {
                    KidButton {
                        showKidSheet = true
                    }
                } else {
                    IncomingSection(showKidSheet: $showKidSheet, page: $exposurePage, compact: fit.compact)
                }
                RadarLine()
            }
            ProgressCard(rows: fit.progress, showQuiz: $showQuiz)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func sign(_ size: TodayFit.Sign) -> some View {
        let sick = model.activeLog != nil
        let season = model.season
        let leading = sick ? tr("Last run: %lld days", model.lastRunDays()) : tr("Record: %lld days", model.recordDays())
        let trailing = sick ? tr("It was beautiful.") : tr("Season %1$lld · Week %2$lld", season.number, season.week(for: Date()))
        switch size {
        case .tile(let width):
            CounterSign(days: model.streakDays(), isSick: sick, leadingNote: leading, trailingNote: trailing, tileWidth: width)
        case .strip:
            CounterSign(days: model.streakDays(), isSick: sick, leadingNote: leading, trailingNote: trailing, isStrip: true)
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    private var couponSheet: some View {
        if let log = model.activeLog, let germ = model.activeGerm {
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

/// The second way to log a germ: a kid's illness, which starts the parent's countdown.
private struct KidButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.ink)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Is a kid sick?"))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(tr("Start your countdown"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .frame(height: 56)
            .background(palette.ink.opacity(0.07), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Shown while a germ is active: what it is, how long, and the way out.
private struct SickNowCard: View {
    let log: SickLog
    let germ: Germ
    let compact: Bool
    @Binding var showCoupon: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var sinceText: String {
        let style: Date.FormatStyle = Calendar.current.isDateInToday(log.startedAt)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.wide).hour().minute()
        return tr("Since %@", log.startedAt.formatted(style))
    }

    /// The usual length when the case file gives one; otherwise its own wording.
    private var lengthText: String {
        germ.lastsUpToDays == nil ? germ.lasts.value : tr("Usually lasts %@", germ.lasts.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 14) {
            HStack(spacing: 12) {
                GermImage(germ: germ, size: compact ? 50 : 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("%1$@ · Day %2$lld", germ.illness.value, log.dayCount()))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(sinceText + " · " + lengthText)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                    if log.sufferer != .me {
                        Text(tr("Sick: %@", model.name(of: log.sufferer)))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
            }
            if let upTo = germ.lastsUpToDays {
                SickDayBar(day: log.dayCount(), upTo: upTo, attack: germ.boss.attackName, tint: germ.deepTint)
            }
            HStack(spacing: 10) {
                Button {
                    model.askBetter = true
                } label: {
                    Label(tr("I'm better"), systemImage: "checkmark")
                }
                .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                Button {
                    showCoupon = true
                } label: {
                    Label(tr("Nap coupon"), systemImage: "ticket")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
            }
        }
        .petriCard(padding: compact ? 14 : 16)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, style: .continuous)
                .fill(germ.deepTint)
                .frame(width: 6)
        }
    }
}

/// Where today sits against the usual length of the germ, from its case file.
private struct SickDayBar: View {
    let day: Int
    let upTo: Int
    /// The boss attack the parent is living through.
    let attack: String
    let tint: Color
    @Environment(\.palette) private var palette

    private var overdue: Bool { day > upTo }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let fraction = min(1, CGFloat(day) / CGFloat(max(1, upTo)))
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.ink.opacity(0.07))
                    Capsule()
                        .fill(overdue ? palette.coralDeep : tint)
                        .frame(width: max(10, proxy.size.width * fraction))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            Text(overdue ? tr("Longer than usual. Check when to call in the case file.")
                         : tr("Day %1$lld of up to %2$lld · %3$@", day, upTo, attack))
                .font(.footnote.weight(overdue ? .semibold : .regular))
                .foregroundStyle(overdue ? palette.coralInk : palette.inkSecondary)
        }
    }
}

/// The germ's practical advice: every tip, or the one whose turn it is when room is short.
private struct TipsCard: View {
    let germ: Germ
    let day: Int
    let count: Int
    @Environment(\.palette) private var palette

    var body: some View {
        let turn = (max(1, day) - 1) % max(1, germ.tips.count)
        let single = count < germ.tips.count
        let shown = single ? [germ.tips[turn]] : germ.tips
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Next 48 hours"),
                          trailing: single ? tr("Tip %1$lld of %2$lld", turn + 1, germ.tips.count) : nil)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 13) {
                        IconTile(symbol: item.element.icon, background: germ.lightTint, foreground: Color(hex: Swatch.night))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.element.title.value)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            Text(item.element.body.value)
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                NavigationLink(value: germ) {
                    HStack(spacing: 11) {
                        IconTile(symbol: "cross.case.fill", background: palette.coralDeep, size: 28)
                        Text(tr("Case file and when to call"))
                            .font(.callout.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.ink)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
        }
    }
}

/// The kid illness whose incubation window is still relevant; several take turns in the same card.
private struct IncomingSection: View {
    @Binding var showKidSheet: Bool
    @Binding var page: Int
    let compact: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let exposures = model.openExposures
        let index = min(max(0, page), max(0, exposures.count - 1))
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(tr("Incoming"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.ink)
                HStack(spacing: 4) {
                    Circle()
                        .fill(palette.coralInk)
                        .frame(width: 7, height: 7)
                    Text(tr("Live"))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.coralInk)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                if exposures.count > 1 {
                    Button {
                        withAnimation(.snappy) {
                            page = (index + 1) % exposures.count
                        }
                    } label: {
                        Text(tr("%1$lld of %2$lld", index + 1, exposures.count))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(palette.ink.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(tr("Next"))
                }
                Button {
                    showKidSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 30, height: 30)
                        .background(palette.ink.opacity(0.07), in: Circle())
                        .padding(7)
                        .contentShape(Rectangle())
                        .padding(-7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Add a kid's germ"))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            if index < exposures.count {
                let illness = exposures[index]
                TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                    IncomingCard(illness: illness, now: timeline.date, compact: compact)
                }
                .id(illness.id)
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                    let across = value.translation.width
                    guard exposures.count > 1, abs(across) > 48, abs(across) > abs(value.translation.height) else { return }
                    let step = across < 0 ? 1 : exposures.count - 1
                    withAnimation(.snappy) {
                        page = (index + step) % exposures.count
                    }
                })
            }
        }
    }
}

private struct IncomingCard: View {
    let illness: KidIllness
    let now: Date
    let compact: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let germ = model.catalog.germ(illness.germID) {
            let kid = model.kid(illness.kidID)
            VStack(alignment: .leading, spacing: compact ? 12 : 14) {
                header(germ: germ, kid: kid)
                if let window = germ.window(from: illness.startedAt) {
                    timeline(germ: germ, opens: window.opens, closes: window.closes)
                } else {
                    Text(tr("No countdown for this one. The case file explains what to watch for."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                actions(germ: germ)
            }
            .petriCard(padding: compact ? 14 : 16)
        }
    }

    private func header(germ: Germ, kid: Kid?) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: kid?.name ?? "?", gradient: AvatarColors.gradient(kid?.colorIndex ?? 0),
                           size: compact ? 40 : 46)
                GermImage(germ: germ, size: 24, silhouette: model.count(of: germ.id) == 0)
                    .foregroundStyle(palette.ink.opacity(0.35))
                    .padding(2)
                    .background(palette.surface, in: Circle())
                    .offset(x: 8, y: 7)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("%1$@ has %2$@", kid?.name ?? tr("Your kid"), germ.phrase.value))
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(tr("Since %@", illness.startedAt.formatted(.dateTime.weekday(.wide).hour().minute())))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 4)
            if germ.window(from: illness.startedAt) != nil {
                Button {
                    toggleWatch()
                } label: {
                    watchLabel
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var watchLabel: some View {
        let symbol = illness.watching ? "bell.fill" : "bell"
        let ink = illness.watching ? palette.ink : palette.background
        let fill = illness.watching ? palette.ink.opacity(0.08) : palette.ink
        if compact {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink)
                .frame(width: 34, height: 34)
                .background(fill, in: Circle())
                .accessibilityLabel(illness.watching ? tr("Watching") : tr("Watch"))
        } else {
            Label(illness.watching ? tr("Watching") : tr("Watch"), systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(fill, in: Capsule())
        }
    }

    private func timeline(germ: Germ, opens: Date, closes: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IncubationBar(exposedAt: illness.startedAt, opens: opens, closes: closes, now: now, tint: germ.deepTint)
                .padding(.top, 6)
            if !compact {
                HStack {
                    Text(tr("Exposed"))
                    Spacer()
                    Text(tr("Window: %@", germ.showsUp.value))
                }
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
            }
            Text(status(opens: opens, closes: closes))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(now >= opens && now <= closes ? palette.coralInk : palette.ink)
        }
    }

    private func status(opens: Date, closes: Date) -> String {
        if now < opens {
            return tr("Your window opens %@.", opens.formatted(.relative(presentation: .named)))
        }
        if now <= closes {
            let hours = Int(now.timeIntervalSince(illness.startedAt) / 3600)
            return tr("You're in the window. Hour %lld since exposure.", hours)
        }
        return tr("The usual window has passed. Did you dodge it?")
    }

    private func actions(germ: Germ) -> some View {
        HStack(spacing: 10) {
            Button {
                model.logRequest = LogRequest(kidIllnessID: illness.id)
            } label: {
                Label(tr("It got me"), systemImage: "thermometer.medium")
            }
            .buttonStyle(PillButtonStyle(kind: .coral, height: 42))
            Button {
                Haptics.success()
                model.resolveExposure(illness.id, outcome: .dodged)
            } label: {
                Label(tr("Dodged it"), systemImage: "figure.run")
            }
            .buttonStyle(PillButtonStyle(kind: .ghost, height: 42))
        }
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

/// What the crew reported this week, in one line that opens the Crew tab.
private struct RadarLine: View {
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette

    var body: some View {
        if model.hasPass, let state = crew.state, !state.radar.isEmpty {
            let illnesses = state.radar.compactMap { model.catalog.germ($0.germID)?.illness.value }
            Button {
                model.selectedTab = .crew
            } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: "dot.radiowaves.left.and.right", background: palette.coralDeep,
                             foreground: palette.night, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Going around %@", state.crew.name))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Text(illnesses.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(palette.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
                .petriCard(padding: 12)
            }
            .buttonStyle(.plain)
        }
    }
}

struct RadarRow: View {
    let entry: RadarEntry
    let families: Int
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let germ = model.catalog.germ(entry.germID) {
            HStack(spacing: 12) {
                GermImage(germ: germ, size: 34, silhouette: model.count(of: germ.id) == 0)
                    .foregroundStyle(palette.ink.opacity(0.3))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(germ.illness.value)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Spacer()
                        Text(trCount(entry.families, one: "%lld family", other: "%lld families"))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    ProgressView(value: Double(entry.families), total: Double(max(families, entry.families, 1)))
                        .tint(palette.coralDeep)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// The level, the daily quiz while it is open, and the closest thing to unlock; rows drop when room is short.
private struct ProgressCard: View {
    private enum Row: Hashable {
        case level
        case quiz
        case goal
    }

    let rows: TodayFit.Rows
    @Binding var showQuiz: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let goal = GoalEngine.next(data: model.data, catalog: model.catalog, now: Date())
        let questions = model.quizDone() ? 0 : model.quizPlan().count
        let shown = visibleRows(hasQuiz: questions > 0, hasGoal: goal != nil)
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    switch item.element {
                    case .level:
                        NavigationLink {
                            SkillTreeScreen()
                        } label: {
                            levelRow
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(tr("Opens the skill tree"))
                    case .quiz:
                        Button {
                            showQuiz = true
                        } label: {
                            quizRow(questions)
                        }
                        .buttonStyle(.plain)
                    case .goal:
                        if let goal {
                            NavigationLink {
                                SkillTreeScreen()
                            } label: {
                                goalRow(goal)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(tr("Opens the skill tree"))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
        }
    }

    private func visibleRows(hasQuiz: Bool, hasGoal: Bool) -> [Row] {
        let wanted: [Row]
        switch rows {
        case .full: wanted = [.level, .quiz, .goal]
        case .short: wanted = [.level, .quiz]
        case .quizOnly: wanted = [.quiz]
        case .hidden: wanted = []
        }
        return wanted.filter { ($0 != .quiz || hasQuiz) && ($0 != .goal || hasGoal) }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
    }

    private var levelRow: some View {
        let level = model.level
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("Level %1$lld · %2$@", level.number, model.displayTitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text(tr("%1$lld / %2$lld pts", level.progress, level.span))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.inkSecondary)
            }
            ProgressView(value: level.fraction)
                .tint(palette.progress)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func quizRow(_ count: Int) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: "flask.fill", background: palette.lime, foreground: palette.night, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(trCount(count, one: "Daily quiz · %lld question", other: "Daily quiz · %lld questions"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                Text(tr("About a minute · +%lld pts", count * RewardEngine.quizAnswerPoints))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            chevron
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func goalRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: goal.symbol, background: palette.surfaceAlt, foreground: palette.ink, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Next up: %@", goal.title))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                Text(goal.detail)
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            Text(tr("%1$lld of %2$lld", goal.progress, goal.target))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.inkSecondary)
            chevron
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
