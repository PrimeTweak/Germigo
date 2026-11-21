import SwiftUI

/// The home on one page: one character, one number or headline, the week, and two answers.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var flow: SymptomFlow?
    @State private var pendingLog: LogRequest?
    @State private var pendingWanted: KidIllness?
    @State private var wanted: KidIllness?
    @State private var exposurePage = 0
    @State private var pageHeight: CGFloat = 0

    private var mascotTint: Color { Color(hex: Swatch.irisSoft) }

    var body: some View {
        let exposures = model.openExposures
        let index = min(max(0, exposurePage), max(0, exposures.count - 1))
        NavigationStack {
            GeometryReader { proxy in
                let height = pageHeight > 0 ? pageHeight : proxy.size.height
                let side = min(220, max(112, height * 0.28))
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.subheadline)
                            .foregroundStyle(palette.ink.opacity(0.8))
                            .padding(.horizontal, 4)
                        if let log = model.activeLog, let germ = model.activeGerm {
                            SickStage(log: log, germ: germ, side: side, flow: $flow)
                        } else if index < exposures.count, let germ = model.catalog.germ(exposures[index].germID) {
                            ExposureStage(illness: exposures[index], germ: germ, side: side, page: $exposurePage,
                                          pages: exposures.count, flow: $flow)
                                .id(exposures[index].id)
                        } else {
                            CalmStage(side: side, flow: $flow)
                        }
                    }
                    .frame(minHeight: max(0, height - 12), alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .onAppear {
                    settle(proxy.size.height)
                }
                .onChange(of: proxy.size.height) { _, newHeight in
                    settle(newHeight)
                }
            }
            .background(CharacterWash(tint: washTint(exposures: exposures, index: index)))
            .navigationTitle(tr("Today"))
            .toolbar {
                if model.activeLog == nil, index < exposures.count {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            wanted = exposures[index]
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(tr("Wanted poster"))
                    }
                }
                if model.activeLog != nil || !exposures.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            flow = .someone
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(tr("Someone's sick"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .navigationDestination(for: DayRoute.self) { route in
                DayScreen(day: route.day)
            }
            .sheet(item: $flow, onDismiss: handOff) { flow in
                SymptomFlowSheet(flow: flow, onLog: { pendingLog = $0 }, onAdded: { pendingWanted = $0 })
            }
            .sheet(item: $wanted) { illness in
                WantedSheet(illness: illness)
            }
        }
    }

    /// The page keeps the height it had under the large title, so it does not stretch while the title collapses.
    private func settle(_ height: CGFloat) {
        guard height > 200, pageHeight == 0 || height < pageHeight else { return }
        pageHeight = height
    }

    /// The log sheet, or a new kid's wanted poster, opens once the symptom pages have closed.
    private func handOff() {
        if let request = pendingLog {
            pendingLog = nil
            model.logRequest = request
        }
        if let illness = pendingWanted {
            pendingWanted = nil
            wanted = illness
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

/// One sick kid on Today, with the illnesses that keep them in bed.
private struct SickKid: Identifiable {
    let kid: Kid
    let illnessIDs: [UUID]
    var id: UUID { kid.id }
}

/// Under the headline: the signs noted with the way back to the symptom pages, and the way out for a sick kid.
private struct StageActions: View {
    /// The signs of the germ on screen; nil when it was not picked from its symptoms.
    var signs: [String]?
    var onSigns: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var sickKids: [SickKid] {
        let illnesses = model.sickKidIllnesses
        return model.data.kids.compactMap { kid -> SickKid? in
            let ids = illnesses.filter { $0.kidID == kid.id }.map { $0.id }
            return ids.isEmpty ? nil : SickKid(kid: kid, illnessIDs: ids)
        }
    }

    var body: some View {
        let kids = sickKids
        let titles = Symptom.ordered(Set(signs ?? [])).map { $0.title }
        if signs != nil || !kids.isEmpty {
            VStack(spacing: 10) {
                if !titles.isEmpty {
                    Text(titles.joined(separator: " · "))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        buttons(kids)
                    }
                    VStack(spacing: 8) {
                        buttons(kids)
                    }
                }
            }
            .padding(.top, 12)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func buttons(_ kids: [SickKid]) -> some View {
        if signs != nil {
            Button(action: onSigns) {
                capsule {
                    Label(tr("Symptoms changed?"), systemImage: "magnifyingglass")
                }
            }
            .buttonStyle(PressableStyle())
        }
        if kids.count == 1, let sick = kids.first {
            Button {
                model.cheerKidBetter(sick.illnessIDs, on: Date())
            } label: {
                better(look: sick.kid.colorIndex, title: tr("%@ is better", sick.kid.name))
            }
            .buttonStyle(PressableStyle())
        } else if let first = kids.first {
            Menu {
                ForEach(kids) { sick in
                    Button(tr("%@ is better", sick.kid.name)) {
                        model.cheerKidBetter(sick.illnessIDs, on: Date())
                    }
                }
            } label: {
                better(look: first.kid.colorIndex, title: tr("Who's better?"))
            }
        }
    }

    private func better(look: Int, title: String) -> some View {
        capsule {
            HStack(spacing: 8) {
                BuddyView(look: look, sick: true, size: 30, lively: true)
                Text(title)
                Image(systemName: "sparkles")
            }
            .padding(.leading, -10)
        }
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.callout.weight(.semibold))
            .foregroundStyle(palette.accent)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(palette.isDark ? palette.surface : palette.background, in: Capsule())
            .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.08), radius: 8, x: 0, y: 3)
    }
}

/// Nobody is sick: the mascot sleeps on the counter.
private struct CalmStage: View {
    let side: CGFloat
    @Binding var flow: SymptomFlow?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let days = model.streakDays()
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            NappingMascot(side: model.sickKidIllnesses.isEmpty ? side : side * 0.8)
            Text(tr("This household has gone"))
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 12)
            Text(verbatim: String(days))
                .font(.system(size: side >= 190 ? 112 : 84, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: days)
            Text(trCount(days, one: "day without a germ", other: "days without a germ"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
            StageActions()
            WeekStrip(showsRecord: true)
                .padding(.top, 16)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                FaceTile(tr("I'm sick")) {
                    flow = .me
                } face: {
                    BuddyView(look: model.data.hostLook, sick: true, lively: true)
                }
                FaceTile(tr("Someone's sick")) {
                    flow = .someone
                } face: {
                    othersFace
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// The kids' and the partner's characters, two at most, or a plus when the parent is alone.
    @ViewBuilder
    private var othersFace: some View {
        let looks = model.data.kids.map { $0.colorIndex } + (model.data.partnerName == nil ? [] : [model.data.partnerLook])
        if looks.count > 1 {
            ZStack {
                BuddyView(look: looks[1], sick: true, size: 44)
                    .offset(x: 16, y: -6)
                BuddyView(look: looks[0], sick: true, size: 52, lively: true)
                    .offset(x: -10, y: 4)
            }
        } else if let look = looks.first {
            BuddyView(look: look, sick: true, lively: true)
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
    @Binding var flow: SymptomFlow?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var askStillFine = false
    @State private var showCaseFile = false
    @State private var protecting: KidIllness?

    private var window: (opens: Date, closes: Date)? { germ.window(from: illness.startedAt) }
    private var hasPassed: Bool { window.map { Date() > $0.closes } ?? false }

    /// The symptom pages stay one tap away for a mystery, and for a germ that was picked from its signs.
    private var showsSymptoms: Bool {
        germ.id == GermCatalog.mysteryID || !illness.symptoms.isEmpty
    }

    /// Smaller art when more lines share the page.
    private var art: CGFloat {
        showsSymptoms || pages > 1 || !model.sickKidIllnesses.isEmpty ? side * 0.72 : side * 0.9
    }

    var body: some View {
        let kidName = model.kid(illness.kidID)?.name ?? tr("Your kid")
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LivelyCharacter(mood: .stalking) {
                GermImage(germ: germ, size: art)
            }
            StageText(lead: tr("%1$@ brought home %2$@", kidName, germ.phrase.value),
                      headline: tr("%@ is after you", germ.name),
                      detail: germ.id == GermCatalog.mysteryID ? nil : detail)
                .padding(.top, 14)
            StageActions(signs: showsSymptoms ? illness.symptoms : nil) {
                flow = .kidIllness(illness.id)
            }
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
            WeekStrip(showsRecord: false)
                .padding(.top, 14)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                FaceTile(hasPassed ? tr("Dodged it") : tr("Still fine")) {
                    if hasPassed {
                        dodge()
                    } else {
                        askStillFine = true
                    }
                } face: {
                    BuddyView(look: model.data.hostLook, lively: true)
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
    @Binding var flow: SymptomFlow?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showKit = false

    /// A hard hit drops the fight talk, like the reward screen does.
    private var gentle: Bool { log.severity >= 5 }

    private var showsSymptoms: Bool {
        germ.id == GermCatalog.mysteryID || !log.symptoms.isEmpty
    }

    var body: some View {
        let day = log.dayCount()
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LivelyCharacter(mood: .sick) {
                GermImage(germ: germ, size: showsSymptoms || !model.sickKidIllnesses.isEmpty ? side * 0.72 : side * 0.9)
            }
            StageText(lead: lead(day: day), headline: headline(day: day))
                .padding(.top, 14)
            if let left = lifeLeft(day: day) {
                ThinGauge(fraction: left)
                    .frame(width: 240)
                    .padding(.top, 14)
            }
            if germ.id != GermCatalog.mysteryID {
                Text(detail(day: day))
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }
            StageActions(signs: showsSymptoms ? log.symptoms : nil) {
                flow = .log(log.id)
            }
            WeekStrip(showsRecord: false)
                .padding(.top, 14)
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
                    BuddyView(look: model.data.hostLook, lively: true)
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

/// The weeks under the counter: a germ marks each sick day, and each day opens its page.
private struct WeekStrip: View {
    let showsRecord: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var shownWeek: Date?

    var body: some View {
        let now = Date()
        let first = DayEngine.firstDay(data: model.data)
        let weeks = Self.weekStarts(from: first, to: now)
        VStack(spacing: 4) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { start in
                        week(start, first: first, now: now)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $shownWeek)
            .defaultScrollAnchor(.trailing)
            .frame(height: 62)
            caption(current: weeks.last)
                .frame(height: 20)
        }
    }

    /// The start of every week from the first day to now, oldest first, two years at most.
    static func weekStarts(from first: Date, to now: Date) -> [Date] {
        let calendar = Calendar.current
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let oldest = calendar.dateInterval(of: .weekOfYear, for: first)?.start ?? current
        let span = min(104, max(0, calendar.dateComponents([.weekOfYear], from: oldest, to: current).weekOfYear ?? 0))
        return (0...span).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
    }

    private func week(_ start: Date, first: Date, now: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                DayDot(day: day, today: today, first: first, germ: germ(on: day, now: now))
                    .cascadeIn(offset)
            }
        }
    }

    private func germ(on day: Date, now: Date) -> Germ? {
        DayEngine.entries(on: day, data: model.data, catalog: model.catalog, now: now).first
            .flatMap { model.catalog.germ($0.germID) }
    }

    @ViewBuilder
    private func caption(current: Date?) -> some View {
        if let shown = shownWeek, let current, shown != current {
            HStack(spacing: 10) {
                Text(range(from: shown))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                Button(tr("This week")) {
                    withAnimation(.snappy) {
                        shownWeek = current
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.accent)
            }
        } else if showsRecord {
            RecordLine()
        }
    }

    private func range(from start: Date) -> String {
        let last = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return (start..<last).formatted(.interval.month(.abbreviated).day())
    }
}

/// One day of the week: its germ when someone was sick, its number otherwise.
private struct DayDot: View {
    let day: Date
    let today: Date
    let first: Date
    let germ: Germ?
    @Environment(\.palette) private var palette

    private var opens: Bool { day >= first && day <= today }

    var body: some View {
        VStack(spacing: 6) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
                .frame(height: 16)
                .accessibilityHidden(true)
            if opens {
                NavigationLink(value: DayRoute(day: day)) {
                    dot
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month(.wide).day()))
                .accessibilityValue(germ.map { $0.illness.value } ?? "")
            } else {
                dot
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        let isToday = day == today
        let quiet = !opens
        return ZStack {
            if let germ {
                Circle()
                    .fill(germ.tileTint(palette))
                Group {
                    if isToday {
                        LivelyCharacter(mood: .stalking, pokes: false) {
                            GermImage(germ: germ, size: 28)
                        }
                    } else {
                        GermImage(germ: germ, size: 28)
                    }
                }
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                Circle()
                    .fill(isToday ? palette.ink : (quiet ? Color.clear : palette.ink.opacity(0.08)))
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(quiet ? .regular : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? palette.background : (quiet ? palette.inkTertiary : palette.ink))
            }
        }
        .frame(width: 40, height: 40)
        .overlay {
            if isToday, germ != nil {
                Circle()
                    .strokeBorder(palette.ink, lineWidth: 2.5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: germ?.id)
    }
}

/// The best run under the week, or a cheer while the current run is the best one.
private struct RecordLine: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var cheer = false

    var body: some View {
        let record = model.recordDays()
        let days = model.streakDays()
        Group {
            if days > 0, days >= record {
                Label(tr("Your best run yet"), systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .symbolEffect(.bounce, value: cheer)
            } else if record > 0 {
                Text(trCount(record, one: "Best run: %lld day", other: "Best run: %lld days"))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .onAppear {
            cheer.toggle()
        }
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
