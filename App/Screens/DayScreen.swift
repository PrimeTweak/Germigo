import SwiftUI

/// A day opened from the week on Today.
struct DayRoute: Hashable {
    let day: Date
}

extension AppModel {
    /// Marks a kid better, then opens their victory: how long it took and their score against the germ.
    func cheerKidBetter(_ ids: [UUID], on day: Date) {
        guard let first = data.kidIllnesses.first(where: { ids.contains($0.id) }) else { return }
        withAnimation(Tempo.settle) {
            for id in ids { markKidBetter(id, on: day) }
        }
        Haptics.success()
        guard let child = kid(first.kidID), let germ = catalog.germ(first.germID),
              let ended = data.kidIllnesses.first(where: { $0.id == first.id }) else { return }
        let calendar = Calendar.current
        let span = calendar.dateComponents([.day], from: calendar.startOfDay(for: ended.startedAt),
                                           to: calendar.startOfDay(for: ended.endedAt ?? day)).day ?? 0
        let wins = data.kidIllnesses.filter { $0.kidID == child.id && $0.germID == germ.id && $0.endedAt != nil }.count
        pendingKidVictory = KidVictory(kid: child, germ: germ, days: max(1, span + 1), wins: max(1, wins))
    }

    func look(of person: Person) -> Int {
        switch person {
        case .me: return data.hostLook
        case .partner: return data.partnerLook
        case .kid(let id): return kid(id)?.colorIndex ?? 0
        }
    }

    func name(for person: Person) -> String {
        switch person {
        case .me: return displayName
        case .partner: return partnerDisplayName
        case .kid(let id): return kid(id)?.name ?? tr("Your kid")
        }
    }
}

/// What happened on one day: who was sick, with what, and who held on.
struct DayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var day: Date
    @State private var forward = true
    @State private var showPaywall = false

    init(day: Date) {
        _day = State(initialValue: Calendar.current.startOfDay(for: day))
    }

    var body: some View {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let entries = DayEngine.entries(on: day, data: model.data, catalog: model.catalog, now: now)
        let photos = DayEngine.photos(on: day, entries: entries, data: model.data)
        let locked = model.historyStart.map { day < $0 } ?? false
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(subtitle(today: today))
                    .font(.subheadline)
                    .foregroundStyle(palette.ink.opacity(0.8))
                    .padding(.horizontal, 4)
                if locked {
                    LockedDay()
                } else if entries.isEmpty {
                    QuietDay(isToday: day == today)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { item in
                        DayCard(entry: item.element, day: day, isToday: day == today,
                                photos: photos.byEntry[item.element.id] ?? [])
                            .cascadeIn(item.offset)
                    }
                    standing(entries)
                        .cascadeIn(entries.count)
                }
                if !locked, !photos.others.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Other photos"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                        PhotoRow(photos: photos.others)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .id(day)
            .motionTransition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                    removal: .opacity))
        }
        .background(CharacterWash(tint: washTint(locked ? [] : entries), reach: 0.45))
        .navigationTitle(day.formatted(.dateTime.weekday(.wide)).localizedCapitalized)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if let first = model.historyStart, day <= first {
                        showPaywall = true
                    } else {
                        step(-1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(day <= DayEngine.firstDay(data: model.data))
                .accessibilityLabel(tr("Previous day"))
                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(day >= today)
                .accessibilityLabel(tr("Next day"))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func subtitle(today: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, equalTo: today, toGranularity: .year) {
            return day.formatted(.dateTime.month(.wide).day())
        }
        return day.formatted(.dateTime.month(.wide).day().year())
    }

    private func step(_ offset: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: offset, to: day) else { return }
        forward = offset > 0
        withAnimation(Tempo.quick) {
            day = Calendar.current.startOfDay(for: next)
        }
    }

    private func washTint(_ entries: [DayEntry]) -> Color {
        entries.first.flatMap { model.catalog.germ($0.germID) }?.deepTint ?? Color(hex: Swatch.irisSoft)
    }

    /// Everyone not sick that day.
    private func healthy(_ entries: [DayEntry]) -> [Person] {
        let sick = Set(entries.map { $0.person })
        var everyone: [Person] = [.me]
        if model.data.partnerName != nil { everyone.append(.partner) }
        everyone += model.data.kids.map { Person.kid($0.id) }
        return everyone.filter { !sick.contains($0) }
    }

    /// The healthy ones that day, hopping in place.
    @ViewBuilder
    private func standing(_ entries: [DayEntry]) -> some View {
        let people = healthy(entries)
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("Still standing"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                HStack(spacing: 18) {
                    ForEach(people, id: \.self) { person in
                        VStack(spacing: 4) {
                            BuddyView(look: model.look(of: person), size: 46, lively: true, pokes: true)
                            Text(model.name(for: person))
                                .font(.caption)
                                .foregroundStyle(palette.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
        }
    }
}

/// One sick person on the day: who, with what, the signs, and the way out.
private struct DayCard: View {
    let entry: DayEntry
    let day: Date
    let isToday: Bool
    let photos: [PatientPhoto]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var seed: PhotoSeed?
    @State private var showPaywall = false

    var body: some View {
        if let germ = model.catalog.germ(entry.germID) {
            let name = model.name(for: entry.person)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    BuddyView(look: model.look(of: entry.person), sick: !entry.isLastDay, size: 56, lively: true, pokes: true)
                        .id(entry.isLastDay)
                        .motionTransition(.scale(scale: 0.3).combined(with: .opacity))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(status(germ))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 4)
                    NavigationLink(value: germ) {
                        GermImage(germ: germ, size: 46)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(tr("Case file"))
                }
                let signs = Symptom.ordered(Set(entry.symptoms))
                if !signs.isEmpty {
                    ChipRows {
                        ForEach(signs, id: \.id) { sign in
                            Text(sign.title)
                                .font(.subheadline)
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(palette.background, in: Capsule())
                        }
                    }
                }
                PhotoRow(photos: photos) {
                    guard model.hasPass else {
                        showPaywall = true
                        return
                    }
                    seed = PhotoSeed(person: entry.person, takenAt: moment, link: PhotoLink(entry))
                }
                actions(name: name)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .phaseAnimator([0.0, 0.85], trigger: photos.count) { card, flash in
                card.overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(flash))
                        .allowsHitTesting(false)
                }
            } animation: { flash in
                flash > 0 ? .easeIn(duration: 0.06) : .easeOut(duration: 0.45)
            }
            .sheet(item: $seed) { seed in
                AddPhotoSheet(seed: seed)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    /// When a new photo is dated by default: now for today, midday for a past day.
    private var moment: Date {
        isToday ? Date() : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private func status(_ germ: Germ) -> String {
        if let length = entry.length {
            return tr("%1$@, day %2$lld of %3$lld", germ.illness.value, entry.dayNumber, length)
        }
        return tr("%1$@, day %2$lld", germ.illness.value, entry.dayNumber)
    }

    @ViewBuilder
    private func actions(name: String) -> some View {
        if let illnessID = entry.illnessID {
            if entry.isLastDay {
                HStack {
                    Label(tr("Back on their feet"), systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    Spacer(minLength: 8)
                    Button(tr("Still sick")) {
                        withAnimation(Tempo.quick) {
                            model.reopenKidIllness(illnessID)
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                }
            } else {
                pill(isToday ? tr("%@ is better", name) : tr("Better on this day")) {
                    model.cheerKidBetter([illnessID], on: day)
                }
            }
        } else if entry.person == .me, isToday, let logID = entry.logID,
                  model.activeLog?.id == logID {
            pill(tr("I'm better")) {
                model.askBetter = true
            }
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "sparkles")
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(palette.isDark ? palette.surfaceAlt : palette.background, in: Capsule())
                .liftShadow()
        }
        .buttonStyle(PressableStyle())
    }
}

/// A day older than a week, on a free journal.
private struct LockedDay: View {
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 12) {
            NappingMascot(side: 150)
                .overlay(alignment: .topTrailing) { PassLock() }
            Text(tr("This day is in the archives"))
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
            Text(tr("Days older than a week come with the Season Pass."))
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
            Button(tr("See the Season Pass")) {
                showPaywall = true
            }
            .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// Nobody was sick: the mascot naps through it.
private struct QuietDay: View {
    let isToday: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            NappingMascot(side: 170)
            Text(tr("Nothing to report"))
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
            Text(isToday ? tr("Nobody is sick today. Knock on wood.") : tr("Nobody was sick. Suspiciously quiet."))
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }
}
