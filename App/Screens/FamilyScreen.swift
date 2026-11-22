import SwiftUI

/// Who the edit sheet of the family tab is about.
private enum FamilyMember: Identifiable, Hashable {
    case kid(Kid)
    case newKid
    case me
    case partner

    var id: String {
        switch self {
        case .kid(let kid): return kid.id.uuidString
        case .newKid: return "new-kid"
        case .me: return "me"
        case .partner: return "partner"
        }
    }
}

/// What the family tab knows about one person today: sick with what, or fine since when.
private struct PersonStatus {
    let germ: Germ?
    let line: String
    /// The kid's illnesses still going on, for "Better".
    let illnessIDs: [UUID]
    /// The parent's germ still going on, for "Better".
    let logID: UUID?

    var sick: Bool { germ != nil }
}

extension AppModel {
    /// Everyone in the household: the kids, the parent, then the partner when there is one.
    var people: [Person] {
        data.kids.map { Person.kid($0.id) } + [.me] + (data.partnerName == nil ? [] : [.partner])
    }
}

/// The household tab: the sick ones first, each card opening that person's file.
struct FamilyScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: FamilyMember?
    @State private var showPaywall = false

    var body: some View {
        let everyone = model.people
        let people = everyone.filter { status(of: $0).sick } + everyone.filter { !status(of: $0).sick }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(people.enumerated()), id: \.element) { item in
                        let state = status(of: item.element)
                        NavigationLink(value: item.element) {
                            FamilyCard(person: item.element, status: state)
                        }
                        .buttonStyle(PressableStyle())
                        .overlay(alignment: .bottomTrailing) {
                            BetterButton(person: item.element, status: state)
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                        }
                        .cascadeIn(item.offset)
                    }
                    RecordTiles(showPaywall: $showPaywall)
                        .padding(.top, 4)
                        .cascadeIn(people.count)
                    FamilyCouch {
                        editing = .partner
                    }
                    .cascadeIn(people.count + 1)
                    footnote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .animation(Tempo.settle, value: people)
            }
            .background(CharacterWash(tint: TabWash.family))
            .navigationTitle(tr("Family"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if model.canAddKid {
                            editing = .newKid
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: model.canAddKid ? "plus" : "lock.fill")
                    }
                    .accessibilityLabel(tr("Add a kid"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .navigationDestination(for: Person.self) { person in
                PersonFileScreen(person: person)
            }
            .sheet(item: $editing) { member in
                PersonEditSheet(member: member)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func status(of person: Person) -> PersonStatus {
        FamilyStatus.status(of: person, model: model)
    }

    /// What the tab keeps private, and what the Season Pass adds for those without it.
    private var footnote: some View {
        VStack(spacing: 4) {
            Label(tr("First names only. They never leave this phone."), systemImage: "lock.fill")
            if !model.hasPass {
                Text(tr("You and one kid are free. The Season Pass covers the whole household."))
            }
        }
        .font(.footnote)
        .foregroundStyle(palette.inkSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

/// The household's shared records as three tiles: the album, the doctor's file and the logbook.
private struct RecordTiles: View {
    @Binding var showPaywall: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.data.logs.count + model.data.kidIllnesses.count
        let photos = model.data.photos.count
        HStack(alignment: .top, spacing: 10) {
            NavigationLink {
                AlbumScreen()
            } label: {
                RecordTile(title: tr("Album"),
                           value: photos == 0 ? tr("No photos yet") : trCount(photos, one: "%lld photo", other: "%lld photos"),
                           count: photos,
                           tint: Color(hex: Swatch.skyLight)) {
                    AlbumCover()
                }
            }
            .buttonStyle(PressableStyle())
            if model.hasPass {
                NavigationLink {
                    DoctorSummaryScreen()
                } label: {
                    doctorTile(locked: false)
                }
                .buttonStyle(PressableStyle())
            } else {
                Button {
                    showPaywall = true
                } label: {
                    doctorTile(locked: true)
                }
                .buttonStyle(PressableStyle())
            }
            NavigationLink {
                LogbookScreen()
            } label: {
                RecordTile(title: tr("Logbook"),
                           value: entries == 0 ? tr("Nothing yet") : trCount(entries, one: "%lld entry", other: "%lld entries"),
                           count: entries,
                           tint: Color(hex: Swatch.lilac)) {
                    Image("record-logbook")
                        .resizable()
                        .scaledToFit()
                }
            }
            .buttonStyle(PressableStyle())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func doctorTile(locked: Bool) -> some View {
        RecordTile(title: tr("For the doctor"), value: locked ? tr("Season Pass") : tr("Share a file"),
                   tint: Color(hex: Swatch.mint), locked: locked) {
            Image("record-doctor")
                .resizable()
                .scaledToFit()
        }
    }
}

/// One record tile: its character, its name and what it holds. The character wiggles once when something new lands in it.
private struct RecordTile<Art: View>: View {
    let title: String
    let value: String
    var count = 0
    let tint: Color
    var locked = false
    @ViewBuilder let art: Art
    @State private var seen: Int?
    @State private var wiggles = 0
    @State private var onScreen = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(spacing: 2) {
            art
                .frame(width: 72, height: 72)
                .keyframeAnimator(initialValue: 0.0, trigger: wiggles) { content, angle in
                    content.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-8, duration: 0.12)
                        CubicKeyframe(7, duration: 0.14)
                        CubicKeyframe(-5, duration: 0.14)
                        CubicKeyframe(3, duration: 0.12)
                        CubicKeyframe(0, duration: 0.12)
                    }
                }
                .shadow(color: .black.opacity(0.14), radius: 4, y: 4)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            shape
                .fill(palette.background)
                .overlay(shape.fill(tint.opacity(palette.isDark ? 0.22 : 0.16)))
        }
        .overlay(alignment: .topTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(12)
                    .accessibilityLabel(tr("Needs the Season Pass"))
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .onAppear {
            onScreen = true
            notice()
        }
        .onDisappear { onScreen = false }
        .onChange(of: count) { _, _ in
            if onScreen { notice() }
        }
    }

    private func notice() {
        if let seen, count > seen, !reduceMotion {
            wiggles += 1
        }
        seen = count
    }
}

/// The album's tile: its own character, or the two newest photos once there are some.
private struct AlbumCover: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let newest = model.data.photos.sorted { $0.takenAt > $1.takenAt }.prefix(2)
        if newest.isEmpty {
            Image("record-album")
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                ForEach(Array(newest.enumerated()).reversed(), id: \.element.id) { item in
                    PhotoThumb(id: item.element.id, side: 50, radius: 11)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(.white, lineWidth: 3)
                        }
                        .rotationEffect(.degrees(newest.count == 1 ? -4 : (item.offset == 0 ? 7 : -11)))
                        .offset(x: newest.count == 1 ? 0 : (item.offset == 0 ? 9 : -9),
                                y: newest.count == 1 ? 0 : (item.offset == 0 ? 6 : -4))
                }
            }
        }
    }
}

/// Where each person sits on the couch: heads shrink and close up as the household grows.
private struct CouchSeats {
    let count: Int
    /// The couch art is laid out for this width.
    static let width: CGFloat = 320
    static let height: CGFloat = 166
    /// The span of the seat cushions, in the couch's own points.
    private static let seat: ClosedRange<CGFloat> = 52...268
    /// Where heads rest on the seat.
    private static let rest: CGFloat = 104

    var head: CGFloat {
        let span = Self.seat.upperBound - Self.seat.lowerBound
        return min(70, span / CGFloat(max(1, count)) * 1.05)
    }

    func center(of index: Int) -> CGPoint {
        let span = Self.seat.upperBound - Self.seat.lowerBound
        let step = count > 1 ? min(71.5, (span - head) / CGFloat(count - 1)) : 0
        let middle = (Self.seat.lowerBound + Self.seat.upperBound) / 2
        return CGPoint(x: middle + (CGFloat(index) - CGFloat(count - 1) / 2) * step, y: Self.rest - head / 2)
    }
}

/// The household on the couch, a line that follows who is sick, and a free seat while the partner is missing.
private struct FamilyCouch: View {
    let addPartner: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let people = model.people
        let missingPartner = model.data.partnerName == nil
        let seats = CouchSeats(count: people.count + (missingPartner ? 1 : 0))
        VStack(spacing: 3) {
            ZStack {
                Image("mascot-awake")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 87, height: 87)
                    .rotationEffect(.degrees(-11))
                    .position(x: 21, y: 40)
                    .accessibilityHidden(true)
                Image("family-couch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: CouchSeats.width)
                    .position(x: CouchSeats.width / 2, y: 32 + CouchSeats.width / 4.8)
                    .accessibilityHidden(true)
                ForEach(Array(people.enumerated()), id: \.element) { item in
                    BuddyView(look: model.look(of: item.element),
                              sick: FamilyStatus.status(of: item.element, model: model).sick,
                              size: seats.head, leads: true, pokes: true,
                              phase: Double(item.offset) * CharacterPose.accentCycle / Double(max(1, people.count)))
                        .position(seats.center(of: item.offset))
                }
                if missingPartner {
                    Button(action: addPartner) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.ink.opacity(0.62))
                            .frame(width: seats.head * 0.79, height: seats.head * 0.79)
                            .background(.white.opacity(0.3), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(palette.ink.opacity(0.45), style: StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(tr("Add your partner"))
                    .position(seats.center(of: people.count))
                }
            }
            .frame(width: CouchSeats.width, height: CouchSeats.height)
            .accessibilityElement(children: .contain)
            Text(line)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            if missingPartner {
                Text(tr("One seat saved for your partner."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    /// Calm lines take turns by the day; a sick household gets its own.
    private var line: String {
        let people = model.people
        let sick = people.filter { FamilyStatus.status(of: $0, model: model).sick }
        if sick.isEmpty {
            let calm = [tr("Everyone's fine. Suspicious."), tr("Nobody's sick. Don't say it out loud."),
                        tr("The couch is quiet. Too quiet.")]
            let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
            return calm[day % calm.count]
        }
        if sick.count > 1 {
            return sick.count == people.count ? tr("Everyone's down. Send soup.") : tr("%lld down. Hold the line.", sick.count)
        }
        return sick[0] == .me ? tr("You're down. Hold the line.") : tr("%@ is down. Hold the line.", model.name(for: sick[0]))
    }
}

/// How each person is doing today, from the journal.
private enum FamilyStatus {
    @MainActor
    static func status(of person: Person, model: AppModel) -> PersonStatus {
        let now = Date()
        switch person {
        case .kid(let id):
            let going = model.sickKidIllnesses.filter { $0.kidID == id }.sorted { $0.startedAt > $1.startedAt }
            if let illness = going.first, let germ = model.catalog.germ(illness.germID) {
                return PersonStatus(germ: germ, line: tr("%1$@, day %2$lld", germ.illness.value,
                                                         StreakMath.days(from: illness.startedAt, to: now) + 1),
                                    illnessIDs: going.map { $0.id }, logID: nil)
            }
            let ends = model.data.kidIllnesses.filter { $0.kidID == id }
                .map { DayEngine.kidEnd($0, catalog: model.catalog, now: now) }
            guard let last = ends.max() else {
                return PersonStatus(germ: nil, line: tr("Nothing brought home yet"), illnessIDs: [], logID: nil)
            }
            return PersonStatus(germ: nil, line: fine(since: last, now: now), illnessIDs: [], logID: nil)
        case .me, .partner:
            let mine = person == .me
            let logs = model.data.logs.filter { mine ? $0.sufferer.includesMe : $0.sufferer.includesPartner }
            if let log = logs.first(where: { $0.isActive }), let germ = model.catalog.germ(log.germID) {
                return PersonStatus(germ: germ, line: tr("%1$@, day %2$lld", germ.illness.value, log.dayCount(now: now)),
                                    illnessIDs: [], logID: log.id)
            }
            let last = logs.compactMap { $0.endedAt }.max() ?? model.data.installedAt
            return PersonStatus(germ: nil, line: fine(since: last, now: now), illnessIDs: [], logID: nil)
        }
    }

    private static func fine(since date: Date, now: Date) -> String {
        let days = StreakMath.days(from: date, to: now)
        return days == 0 ? tr("Better today") : trCount(days, one: "Fine for %lld day", other: "Fine for %lld days")
    }
}

/// One person on the family tab: their character, how they are, and while sick the germ and its photos.
private struct FamilyCard: View {
    let person: Person
    let status: PersonStatus
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                BuddyView(look: model.look(of: person), sick: status.sick, size: 60)
                    .id(status.sick)
                    .motionTransition(.scale(scale: 0.4).combined(with: .opacity))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name(for: person))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(status.line)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            if let germ = status.germ {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        GermImage(germ: germ, size: 26)
                        Text(germ.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .frame(height: 34)
                    .background(germ.tileTint(palette), in: Capsule())
                    ForEach(recentPhotos.prefix(2)) { photo in
                        PhotoThumb(id: photo.id, side: 42, radius: 11)
                    }
                    Spacer(minLength: 96)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.germ.map { $0.tileTint(palette).opacity(0.55) } ?? palette.surface,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// The photos of the illness going on, newest first.
    private var recentPhotos: [PatientPhoto] {
        model.data.photos
            .filter { photo in
                photo.person == person
                    && (photo.logID.map { $0 == status.logID } ?? false
                        || photo.illnessID.map { status.illnessIDs.contains($0) } ?? false)
            }
            .sorted { $0.takenAt > $1.takenAt }
    }

}

/// "Better" on a sick card, laid over it so the tap never opens the file.
private struct BetterButton: View {
    let person: Person
    let status: PersonStatus
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if !status.illnessIDs.isEmpty {
            pill {
                model.cheerKidBetter(status.illnessIDs, on: Date())
            }
        } else if status.logID != nil, person == .me {
            pill {
                model.askBetter = true
            }
        }
    }

    private func pill(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(tr("Better now"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(palette.isDark ? palette.surfaceAlt : palette.background, in: Capsule())
                .liftShadow()
                .hitTarget(height: 34)
        }
        .buttonStyle(PressableStyle())
    }
}

/// One person's file: who they are, then every illness with its signs and photos, ready for a doctor.
private struct PersonFileScreen: View {
    let person: Person
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var editing: FamilyMember?
    /// The big numbers, the same size as on Trophies and following the text size set in iOS.
    @ScaledMetric(relativeTo: .title) private var figureSize: CGFloat = 28

    private var member: FamilyMember? {
        switch person {
        case .kid(let id): return model.kid(id).map { FamilyMember.kid($0) }
        case .me: return .me
        case .partner: return .partner
        }
    }

    var body: some View {
        let status = FamilyStatus.status(of: person, model: model)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    BuddyView(look: model.look(of: person), sick: status.sick, size: 96, leads: true, pokes: true)
                        .frame(width: 140, height: 140)
                        .background(Buddy.tint(model.look(of: person)).opacity(palette.isDark ? 0.24 : 0.34), in: Circle())
                    Text(status.line)
                        .font(.callout)
                        .foregroundStyle(palette.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                numbers
                HealthHistory(person: person, since: nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(CharacterWash(tint: Buddy.tint(model.look(of: person)), reach: 0.4))
        .navigationTitle(model.name(for: person))
        .toolbar {
            if let member {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = member
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(tr("Edit %@", model.name(for: person)))
                }
            }
        }
        .sheet(item: $editing) { member in
            PersonEditSheet(member: member)
        }
        .onChange(of: model.people) { _, people in
            if !people.contains(person) { dismiss() }
        }
    }

    /// Up to three numbers about this person, from the journal.
    private var numbers: some View {
        let values: [(Int, String)]
        switch person {
        case .kid(let id):
            let illnesses = model.data.kidIllnesses.filter { $0.kidID == id }
            values = [(illnesses.count, tr("brought home")),
                      (model.data.logs.filter { $0.source == .kid(id) }.count, tr("got you")),
                      (illnesses.filter { $0.outcome == .dodged }.count, tr("you dodged"))]
        case .me:
            let logs = model.data.logs.filter { $0.sufferer.includesMe }
            values = [(logs.count, tr("germs caught")), (logs.reduce(0) { $0 + $1.dayCount() }, tr("days sick")),
                      (model.data.kidIllnesses.filter { $0.outcome == .dodged }.count, tr("germs dodged"))]
        case .partner:
            let logs = model.data.logs.filter { $0.sufferer.includesPartner }
            values = [(logs.count, tr("germs caught")), (logs.reduce(0) { $0 + $1.dayCount() }, tr("days sick"))]
        }
        return HStack(alignment: .top, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 0) {
                    RollingNumber(value: item.element.0)
                        .font(.system(size: figureSize, weight: .bold))
                        .foregroundStyle(palette.ink)
                    Text(item.element.1)
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .germigoCard(radius: 24, padding: 12)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The partner's sheet from Family, opened wherever the partner is still missing.
struct PartnerEditSheet: View {
    var body: some View {
        PersonEditSheet(member: .partner)
    }
}

/// The pencil of a card: the name, the character, and the way out of the household.
private struct PersonEditSheet: View {
    let member: FamilyMember
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var look = 0
    @State private var showsSick = false
    @State private var confirmRemove = false
    @State private var didPrefill = false

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var title: String {
        switch member {
        case .kid(let kid): return kid.name
        case .newKid: return tr("New kid")
        case .me: return tr("You")
        case .partner: return tr("Partner")
        }
    }

    /// Only the parent may stay without a name.
    private var canSave: Bool {
        member == .me || !trimmed.isEmpty
    }

    /// Who the sheet can take out of the household: a kid, or a partner already added.
    private var removable: String? {
        switch member {
        case .kid(let kid): return kid.name
        case .partner: return model.data.partnerName
        case .newKid, .me: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    preview
                        .frame(maxWidth: .infinity)
                    label(tr("Name"))
                    TextField(member == .me ? tr("You") : tr("First name"), text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    label(tr("Character"))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(0..<Looks.count, id: \.self) { index in
                            choice(index)
                        }
                    }
                    if let removable {
                        Button(tr("Remove %@", removable)) {
                            confirmRemove = true
                        }
                        .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                        .padding(.top, 26)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Save"))
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(tr("Remove %@?", removable ?? ""), isPresented: $confirmRemove, titleVisibility: .visible) {
                Button(tr("Remove"), role: .destructive) {
                    remove()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                if case .kid = member {
                    Text(tr("Their germs, photos and countdowns are removed too. Your own journal stays."))
                }
            }
            .onAppear(perform: prefill)
        }
    }

    /// The chosen character, large. A tap shows it sick, then well again.
    private var preview: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.tap()
                showsSick.toggle()
            } label: {
                BuddyView(look: look, sick: showsSick, size: 104, leads: true)
                    .frame(width: 156, height: 156)
                    .background(Buddy.tint(look).opacity(palette.isDark ? 0.24 : 0.34), in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(tr("Tap the character to see it sick."))
            Text(tr("Tap the character to see it sick."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .accessibilityHidden(true)
        }
        .padding(.top, 12)
        .animation(Tempo.pop, value: look)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.inkSecondary)
            .padding(.horizontal, 4)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func choice(_ index: Int) -> some View {
        let isOn = Buddy.index(look) == index
        return Button {
            Haptics.tap()
            look = index
        } label: {
            Circle()
                .fill(Buddy.tint(index).opacity(palette.isDark ? 0.24 : 0.34))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        BuddyView(look: index, sick: showsSick, size: proxy.size.width * 0.62)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(isOn ? palette.ink : Color.clear, lineWidth: 3)
                        .padding(-5)
                }
                .padding(5)
                .scaleEffect(isOn ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("Character %lld", index + 1))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        switch member {
        case .kid(let kid):
            name = kid.name
            look = kid.colorIndex
        case .newKid:
            look = model.nextKidLook
        case .me:
            name = model.data.profileName
            look = model.data.hostLook
        case .partner:
            name = model.data.partnerName ?? ""
            look = model.data.partnerLook
        }
    }

    private func save() {
        guard canSave else { return }
        switch member {
        case .kid(let kid):
            var updated = kid
            updated.name = trimmed
            updated.colorIndex = look
            model.saveKid(updated)
        case .newKid:
            model.saveKid(Kid(name: trimmed, colorIndex: look))
        case .me:
            model.setProfileName(trimmed)
            model.setHostLook(look)
        case .partner:
            model.setPartnerName(trimmed)
            model.setPartnerLook(look)
        }
        dismiss()
    }

    private func remove() {
        switch member {
        case .kid(let kid): model.removeKid(kid.id)
        case .partner: model.setPartnerName("")
        case .newKid, .me: break
        }
        dismiss()
    }
}
