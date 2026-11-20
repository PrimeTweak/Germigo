import SwiftUI

struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showSettings = false
    @State private var showKidSheet = false
    @State private var showQuiz = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    sign
                    if let log = model.activeLog, let germ = model.activeGerm {
                        SickNowCard(log: log, germ: germ)
                        TipsCard(germ: germ)
                        QuizTeaser(showQuiz: $showQuiz)
                    } else {
                        HoldToLogButton {
                            model.logRequest = LogRequest()
                        }
                        QuizTeaser(showQuiz: $showQuiz)
                        IncomingSection(showKidSheet: $showKidSheet)
                        RadarTeaser()
                    }
                    LevelCard()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
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
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
        }
    }

    private var sign: some View {
        let sick = model.activeLog != nil
        let season = model.season
        let leading = sick ? tr("Last run: %lld days", model.lastRunDays()) : tr("Record: %lld days", model.recordDays())
        let trailing = sick ? tr("It was beautiful.") : tr("Season %1$lld · Week %2$lld", season.number, season.week(for: Date()))
        return CounterSign(days: model.streakDays(), isSick: sick, leadingNote: leading, trailingNote: trailing)
    }
}

/// The daily quiz, waiting on Today until it is done.
private struct QuizTeaser: View {
    @Binding var showQuiz: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let plan = model.quizPlan()
        let next = model.quizAnswers().count
        if next < plan.count && !model.quizDone() {
            Button {
                showQuiz = true
            } label: {
                HStack(spacing: 13) {
                    IconTile(symbol: "flask.fill", background: palette.lime, foreground: palette.night, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trCount(plan.count, one: "Daily quiz · %lld question", other: "Daily quiz · %lld questions"))
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Text(teaser(plan[next]))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
                .petriCard()
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.lime, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func teaser(_ question: QuizQuestion) -> String {
        switch question.kind {
        case .myth: return tr("Myth or fact? %@", question.prompt)
        case .whoAmI: return tr("Who am I? %@", question.prompt)
        case .showsUp, .lasts: return question.prompt
        }
    }
}

/// Shown while a germ is active: what it is, how long, and the way out.
private struct SickNowCard: View {
    let log: SickLog
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showCoupon = false

    private var sinceText: String {
        let style: Date.FormatStyle = Calendar.current.isDateInToday(log.startedAt)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.wide).hour().minute()
        return tr("Since %@", log.startedAt.formatted(style))
    }

    /// The usual length when the Field Notes give one; otherwise their own wording.
    private var lengthText: String {
        germ.lastsUpToDays == nil ? germ.lasts.value : tr("Usually lasts %@", germ.lasts.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                GermImage(germ: germ, size: 58)
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
                SickDayBar(day: log.dayCount(), upTo: upTo, tint: germ.deepTint)
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
        .petriCard()
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, style: .continuous)
                .fill(germ.deepTint)
                .frame(width: 6)
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

/// Where today sits against the usual length of the germ, from its Field Notes.
private struct SickDayBar: View {
    let day: Int
    let upTo: Int
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
            Text(overdue ? tr("Longer than usual. Check when to call in the Field Notes.")
                         : tr("Day %1$lld of up to %2$lld", day, upTo))
                .font(.footnote.weight(overdue ? .semibold : .regular))
                .foregroundStyle(overdue ? palette.coralInk : palette.inkSecondary)
        }
    }
}

/// The germ's practical advice for the next couple of days.
private struct TipsCard: View {
    let germ: Germ
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Next 48 hours"), trailing: tr("Field Notes"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.tips.enumerated()), id: \.offset) { item in
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
                        }
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                NavigationLink(value: germ) {
                    HStack {
                        Text(tr("All Field Notes"))
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(palette.ink)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
            Text(germ.doctor.value)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
        }
    }
}

/// Kid illnesses whose incubation window is still relevant.
private struct IncomingSection: View {
    @Binding var showKidSheet: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Incoming"), trailing: model.openExposures.isEmpty ? nil : tr("Live"))
            if model.openExposures.isEmpty {
                Button {
                    showKidSheet = true
                } label: {
                    HStack(spacing: 13) {
                        IconTile(symbol: "plus", background: palette.surfaceAlt, foreground: palette.ink, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Is a kid sick?"))
                                .font(.headline)
                                .foregroundStyle(palette.ink)
                            Text(tr("Log it to start your incubation countdown."))
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .petriCard()
                }
                .buttonStyle(.plain)
            } else {
                ForEach(model.openExposures) { illness in
                    TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                        IncomingCard(illness: illness, now: timeline.date)
                    }
                }
                Button {
                    showKidSheet = true
                } label: {
                    Label(tr("Add a kid's germ"), systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct IncomingCard: View {
    let illness: KidIllness
    let now: Date
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let germ = model.catalog.germ(illness.germID) {
            let kid = model.kid(illness.kidID)
            VStack(alignment: .leading, spacing: 14) {
                header(germ: germ, kid: kid)
                if let window = germ.window(from: illness.startedAt) {
                    timeline(germ: germ, opens: window.opens, closes: window.closes)
                } else {
                    Text(tr("No countdown for this one. The Field Notes explain what to watch for."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                actions(germ: germ)
            }
            .petriCard()
        }
    }

    private func header(germ: Germ, kid: Kid?) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: kid?.name ?? "?", gradient: AvatarColors.gradient(kid?.colorIndex ?? 0), size: 46)
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
                    Label(illness.watching ? tr("Watching") : tr("Watch"),
                          systemImage: illness.watching ? "bell.fill" : "bell")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(illness.watching ? palette.ink : palette.background)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(illness.watching ? palette.ink.opacity(0.08) : palette.ink, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeline(germ: Germ, opens: Date, closes: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IncubationBar(exposedAt: illness.startedAt, opens: opens, closes: closes, now: now, tint: germ.deepTint)
                .padding(.top, 6)
            HStack {
                Text(tr("Exposed"))
                Spacer()
                Text(tr("Window: %@", germ.showsUp.value))
            }
            .font(.caption)
            .foregroundStyle(palette.inkSecondary)
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

/// A glance at what the crew reported this week.
private struct RadarTeaser: View {
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette

    var body: some View {
        if model.hasPass, let state = crew.state, !state.radar.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Going around %@", state.crew.name), trailing: tr("This week"))
                VStack(spacing: 0) {
                    ForEach(Array(state.radar.enumerated()), id: \.element.id) { item in
                        if item.offset > 0 {
                            Divider()
                        }
                        RadarRow(entry: item.element, families: state.crew.families)
                            .padding(.vertical, 10)
                    }
                }
                .petriCard(padding: 0)
            }
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

/// Level, worn title, progress to the next level, and the closest thing to unlock.
private struct LevelCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let level = model.level
        let goal = GoalEngine.next(data: model.data, catalog: model.catalog, now: Date())
        NavigationLink {
            SkillTreeScreen()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
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
                if let goal {
                    Divider()
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
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(palette.inkTertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .petriCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint(tr("Opens the skill tree"))
        .padding(.top, 8)
    }
}
