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
    /// Everyone in the household, in the order chosen on the Members page; by default the kids,
    /// the parent, then the partner. Someone added later goes after the chosen ones.
    var people: [Person] {
        let household = data.kids.map { Person.kid($0.id) } + [.me] + (data.partnerName == nil ? [] : [.partner])
        let order = data.memberOrder
        return household.enumerated().sorted { first, second in
            (order.firstIndex(of: first.element) ?? order.count + first.offset)
                < (order.firstIndex(of: second.element) ?? order.count + second.offset)
        }.map { $0.element }
    }
}

/// The Members page, opened from the Family tab once the household is three or more.
private struct MembersRoute: Hashable {}

/// The household tab: up to two people, a card each with the sick ones first; three or more share one card
/// that opens the Members page.
struct FamilyScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: FamilyMember?
    @State private var door: PassReason?
    @State private var choosing = false
    @State private var seatChoice: SeatChoice?

    var body: some View {
        let everyone = model.people
        let people = everyone.filter { status(of: $0).sick } + everyone.filter { !status(of: $0).sick }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if everyone.count >= 3 {
                        NavigationLink(value: MembersRoute()) {
                            MembersCard(people: everyone)
                        }
                        .buttonStyle(PressableStyle())
                        .cascadeIn(0)
                    } else {
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
                    }
                    RecordTiles(door: $door)
                        .padding(.top, 4)
                        .cascadeIn(people.count)
                    FamilyCouch(takeSeat: takeSeat)
                        .cascadeIn(people.count + 1)
                    footnote
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 28)
                .animation(Tempo.settle, value: people)
            }
            .background(CharacterWash(tint: TabWash.family))
            .navigationTitle(tr("Family"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .navigationDestination(for: Person.self) { person in
                PersonFileScreen(person: person)
            }
            .navigationDestination(for: MembersRoute.self) { _ in
                MembersScreen()
            }
            .sheet(item: $editing) { member in
                PersonEditSheet(member: member)
            }
            .sheet(item: $door) { reason in
                PaywallView(reason: reason)
            }
            .sheet(isPresented: $choosing, onDismiss: openChoice) {
                CouchChooser { choice in
                    seatChoice = choice
                    choosing = false
                }
            }
        }
    }

    private func status(of person: Person) -> PersonStatus {
        FamilyStatus.status(of: person, model: model)
    }

    /// The free seat asks who is joining, unless the partner is already there and only a kid can be.
    private func takeSeat() {
        if model.data.partnerName == nil {
            choosing = true
        } else {
            seatChoice = .kid
            openChoice()
        }
    }

    /// Opens the sheet for the one picked, once the chooser has closed.
    private func openChoice() {
        switch seatChoice {
        case .kid:
            if model.canAddKid {
                editing = .newKid
            } else {
                door = .household
            }
        case .partner:
            editing = .partner
        case .duel:
            door = .household
        case nil:
            break
        }
        seatChoice = nil
    }

    /// What the tab keeps private.
    private var footnote: some View {
        Label(tr("First names only. They never leave this phone."), systemImage: "lock.fill")
            .font(.footnote)
            .foregroundStyle(palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}

/// Three people or more: everyone side by side in one card that opens the Members page.
private struct MembersCard: View {
    let people: [Person]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(people, id: \.self) { person in
                VStack(spacing: 6) {
                    BuddyView(look: model.look(of: person),
                              sick: FamilyStatus.status(of: person, model: model).sick,
                              size: people.count > 4 ? 42 : 52)
                    Text(model.name(for: person))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 16)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Members"))
        .accessibilityValue(people.map { model.name(for: $0) }.joined(separator: ", "))
    }
}

/// Everyone's card on one page; the arrows let the cards be dragged into another order.
private struct MembersScreen: View {
    @Environment(AppModel.self) private var model
    @State private var editMode = EditMode.inactive

    var body: some View {
        let people = model.people
        List {
            ForEach(people, id: \.self) { person in
                let state = FamilyStatus.status(of: person, model: model)
                FamilyCard(person: person, status: state)
                    .overlay(alignment: .bottomTrailing) {
                        if !editMode.isEditing {
                            BetterButton(person: person, status: state)
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                        }
                    }
                    .background {
                        NavigationLink(value: person) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: Spacing.page, bottom: 6, trailing: Spacing.page))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                var order = people
                order.move(fromOffsets: from, toOffset: to)
                model.setMemberOrder(order)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CharacterWash(tint: TabWash.family))
        .environment(\.editMode, $editMode)
        .navigationTitle(tr("Members"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(Tempo.settle) {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                } label: {
                    Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                }
                .accessibilityLabel(editMode.isEditing ? tr("Done") : tr("Change the order"))
            }
        }
    }
}

/// The household's shared records as three tiles: the album, the doctor's file and the logbook.
private struct RecordTiles: View {
    @Binding var door: PassReason?
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
                    door = .doctor
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
        RecordTile(title: tr("For the doctor"), value: locked ? PurchaseManager.shared.shortOfferLabel : tr("Share a file"),
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
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
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
                            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
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
struct CouchSeats {
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

/// The couch and the mascot leaning on it, in the space laid out by CouchSeats.
struct CouchBackdrop: View {
    var body: some View {
        ZStack {
            Image("mascot-awake")
                .resizable()
                .scaledToFit()
                .frame(width: 87, height: 87)
                .rotationEffect(.degrees(-11))
                .position(x: 21, y: 40)
            Image("family-couch")
                .resizable()
                .scaledToFit()
                .frame(width: CouchSeats.width)
                .position(x: CouchSeats.width / 2, y: 32 + CouchSeats.width / 4.8)
        }
        .frame(width: CouchSeats.width, height: CouchSeats.height)
        .accessibilityHidden(true)
    }
}

/// The household on the couch, a line that follows who is sick, and a free seat to add someone.
private struct FamilyCouch: View {
    let takeSeat: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    /// Set by the first touch on someone of the household; the invitation bubble then goes for good.
    @AppStorage(HintKeys.couch) private var couchTouched = false
    @State private var showBook = false

    var body: some View {
        let people = model.people
        let seats = CouchSeats(count: people.count + 1)
        VStack(spacing: 3) {
            ZStack {
                CouchBackdrop()
                ForEach(Array(people.enumerated()), id: \.element) { item in
                    BuddyView(look: model.look(of: item.element),
                              sick: FamilyStatus.status(of: item.element, model: model).sick,
                              size: seats.head, leads: true, pokes: true,
                              phase: Double(item.offset) * CharacterPose.accentCycle / Double(max(1, people.count)))
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(Tempo.quick) {
                                couchTouched = true
                            }
                        })
                        .position(seats.center(of: item.offset))
                }
                Button(action: takeSeat) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(0.62))
                        .frame(width: seats.head * 0.79, height: seats.head * 0.79)
                        .background(.white.opacity(0.3), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(palette.ink.opacity(0.45), style: StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
                        }
                        .overlay(alignment: .topTrailing) {
                            if seatNeedsPass {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 20, height: 20)
                                    .background(Color.white, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(tr("Add someone"))
                .accessibilityValue(seatNeedsPass ? tr("Needs the Season Pass") : "")
                .position(seats.center(of: people.count))
                ForEach(model.couchStickers, id: \.id) { sticker in
                    CouchStickerView(sticker: sticker)
                }
            }
            .frame(width: CouchSeats.width, height: CouchSeats.height)
            .overlay(alignment: .top) {
                if !couchTouched && !people.isEmpty {
                    WhisperBubble(text: tr("Tap us. Gently."))
                        .offset(y: -26)
                        .transition(.opacity)
                }
            }
            .accessibilityElement(children: .contain)
            Text(line)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Button {
                showBook = true
            } label: {
                HStack(spacing: 8) {
                    Image("sticker-heart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text(tr("Sticker book · %1$lld of %2$lld", model.earnedStickers().count, StickerBook.all.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(palette.surface, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .sheet(isPresented: $showBook) {
            StickerBookSheet()
        }
    }

    /// Only a second kid can still take the free seat, and that needs the Season Pass.
    private var seatNeedsPass: Bool {
        model.data.partnerName != nil && !model.canAddKid
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

/// A sticker on the couch: hold it, then drag it somewhere else.
private struct CouchStickerView: View {
    let sticker: CouchSticker
    @Environment(AppModel.self) private var model
    @State private var drag = CGSize.zero
    @State private var lifted = false

    var body: some View {
        Image("sticker-" + sticker.id)
            .resizable()
            .scaledToFit()
            .frame(width: 38, height: 38)
            .scaleEffect(lifted ? 1.25 : 1)
            .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 6, y: 3)
            .gesture(LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture())
                .onChanged { value in
                    switch value {
                    case .first(true):
                        if !lifted { Haptics.tick() }
                        lifted = true
                    case .second(true, let move?):
                        drag = move.translation
                    default:
                        break
                    }
                }
                .onEnded { value in
                    if case .second(true, let move?) = value {
                        model.moveCouchSticker(sticker.id, x: sticker.x + move.translation.width,
                                               y: sticker.y + move.translation.height)
                    }
                    drag = .zero
                    lifted = false
                })
            .animation(Tempo.quick, value: lifted)
            .position(x: sticker.x + drag.width, y: sticker.y + drag.height)
            .accessibilityLabel(StickerBook.name(sticker.id))
    }
}

/// Who takes the free seat on the couch, or the couple duel's offer.
private enum SeatChoice {
    case kid
    case partner
    case duel
}

/// The free seat's question: a kid or the partner. A second kid without the Season Pass shows its lock;
/// the partner is free, and the couple duel they open comes with the Pass.
private struct CouchChooser: View {
    let pick: (SeatChoice) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    card(look: model.nextKidLook, title: tr("A kid"),
                         detail: model.canAddKid ? tr("Their own file, and what they bring home") : PurchaseManager.shared.shortOfferLabel,
                         locked: !model.canAddKid) {
                        pick(.kid)
                    }
                    card(look: model.data.partnerLook, title: tr("Your partner"),
                         detail: model.hasPass ? tr("Opens the couple duel") : tr("Free. Their own file and their germs"),
                         locked: false) {
                        pick(.partner)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                if !model.hasPass {
                    duelRow
                }
                Label(tr("First names only. They never leave this phone."), systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Who's joining the couch?"))
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
            }
        }
        .presentationDetents([.medium])
    }

    /// The couple duel, which the Season Pass adds to a partner.
    private var duelRow: some View {
        Button {
            pick(.duel)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "flag.2.crossed.fill", size: 40, tint: Color(hex: Swatch.pink))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Couple duel"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("Who catches more this season"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                PassOfferTag()
            }
            .germilyCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    private func card(look: Int, title: String, detail: String, locked: Bool, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        let tint = Buddy.tint(look)
        return Button(action: action) {
            VStack(spacing: 4) {
                BuddyView(look: look, size: 74)
                    .frame(width: 96, height: 96)
                    .background(tint.opacity(palette.isDark ? 0.4 : 0.7), in: Circle())
                    .padding(.bottom, 6)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                shape
                    .fill(palette.background)
                    .overlay(shape.fill(tint.opacity(palette.isDark ? 0.18 : 0.26)))
            }
            .overlay(shape.strokeBorder(tint.opacity(0.7), lineWidth: 1.5))
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
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
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
            guard let last = logs.compactMap({ $0.endedAt }).max() else {
                return PersonStatus(germ: nil, line: tr("Nothing caught yet"), illnessIDs: [], logID: nil)
            }
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
    /// While the Members page reorders, the list's handles stand where the arrow was.
    @Environment(\.editMode) private var editMode

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
                if editMode?.wrappedValue.isEditing != true {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
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
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
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

    private var member: FamilyMember? {
        switch person {
        case .kid(let id): return model.kid(id).map { FamilyMember.kid($0) }
        case .me: return .me
        case .partner: return .partner
        }
    }

    var body: some View {
        let status = FamilyStatus.status(of: person, model: model)
        let illnesses = PersonFileEngine.illnesses(of: person, data: model.data, catalog: model.catalog, now: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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
                if let current = illnesses.first(where: { $0.goingOn }) {
                    PersonNowCard(person: person, illness: current)
                }
                PersonNumbers(person: person, illnesses: illnesses)
                if model.hasPass {
                    PersonSeasonCard(illnesses: illnesses)
                }
                if person == .me || person == .partner {
                    PersonSuppliersCard(person: person, illnesses: illnesses)
                }
                PersonHistoryCard(person: person, illnesses: illnesses)
                if model.hasPass {
                    if !illnesses.isEmpty {
                        PersonComingBackCard(illnesses: illnesses)
                    }
                    if illnesses.count > 1 {
                        PersonPatternsCard(illnesses: illnesses)
                    }
                    PersonDoctorRow(person: person)
                    PersonPhotosCard(person: person)
                } else {
                    PersonPassCard()
                }
            }
            .padding(.horizontal, Spacing.page)
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
    @State private var door: PassReason?
    /// The look the person had when the sheet opened; it stays theirs even if the Season Pass has ended.
    @State private var original: Int?

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

    private func canKeep(_ look: Int) -> Bool {
        model.isLookOpen(look) || Buddy.index(look) == original
    }

    /// The looks in the picker: the ones Settings shows, plus the person's own even if it is hidden.
    private var offered: [Int] {
        let shown = Set(model.shownLooks)
        return Looks.order.filter { shown.contains($0) || $0 == original }
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
                        .characterLimit(AppModel.nameLimit, text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    label(tr("Character"))
                    looks(offered.filter(canKeep), locked: false)
                    let locked = offered.filter { !canKeep($0) }
                    if !locked.isEmpty {
                        HStack {
                            Text(tr("With the Season Pass"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.inkSecondary)
                            Spacer(minLength: 8)
                            PassOfferTag()
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 22)
                        .padding(.bottom, 10)
                        looks(locked, locked: true)
                    }
                    if let removable {
                        Button(tr("Remove %@", removable)) {
                            confirmRemove = true
                        }
                        .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                        .padding(.top, 26)
                    }
                }
                .padding(.horizontal, Spacing.page)
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
            .sheet(item: $door) { reason in
                PaywallView(reason: reason)
            }
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
            if !canKeep(look) {
                PassOfferLink(reason: .characters)
            }
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

    private func looks(_ indices: [Int], locked: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(indices, id: \.self) { index in
                choice(index, locked: locked)
            }
        }
    }

    /// A look to try. A locked one still shows large above; saving it opens the Season Pass.
    private func choice(_ index: Int, locked: Bool) -> some View {
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
                .overlay(alignment: .bottomTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.onAccent)
                            .frame(width: 22, height: 22)
                            .background(palette.accent, in: Circle())
                            .overlay(Circle().stroke(palette.background, lineWidth: 2.5))
                    }
                }
                .padding(5)
                .scaleEffect(isOn ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? tr("Character %lld", index + 1) + ", " + tr("Needs the Season Pass") : tr("Character %lld", index + 1))
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
        if member != .newKid { original = Buddy.index(look) }
    }

    private func save() {
        guard canSave else { return }
        guard canKeep(look) else {
            door = .characters
            return
        }
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
