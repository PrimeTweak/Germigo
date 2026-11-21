import SwiftUI

/// Who a card or the edit sheet of the family page is about.
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

/// The household: one card per person, built from numbers the journal already holds.
struct FamilyScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: FamilyMember?
    @State private var showPaywall = false

    var body: some View {
        let kids = model.data.kids
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(kids.enumerated()), id: \.element.id) { item in
                    kidCard(item.element)
                        .cascadeIn(item.offset)
                }
                meCard
                    .cascadeIn(kids.count)
                partnerCard
                    .cascadeIn(kids.count + 1)
                Text(tr("Only first names, and they never leave this phone. One kid is free; the Season Pass covers the whole household."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
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
        }
        .sheet(item: $editing) { member in
            PersonEditSheet(member: member)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func ago(_ date: Date) -> String {
        let days = StreakMath.days(from: date, to: Date())
        return days == 0 ? tr("today") : trCount(days, one: "%lld day ago", other: "%lld days ago")
    }

    private func kidCard(_ kid: Kid) -> some View {
        let illnesses = model.data.kidIllnesses.filter { $0.kidID == kid.id }
        let open = illnesses.filter { $0.outcome == .open }.max { $0.startedAt < $1.startedAt }
        let last = illnesses.max { $0.startedAt < $1.startedAt }
        let gotYou = model.data.logs.filter { $0.source == .kid(kid.id) }.count
        let dodged = illnesses.filter { $0.outcome == .dodged }.count
        var status = tr("Nothing brought home yet")
        if let open, let germ = model.catalog.germ(open.germID) {
            status = tr("%1$@, day %2$lld", germ.illness.value, StreakMath.days(from: open.startedAt, to: Date()) + 1)
        } else if let last, let germ = model.catalog.germ(last.germID) {
            status = tr("Last one: %1$@, %2$@", germ.illness.value, ago(last.startedAt))
        }
        return PersonCard(look: kid.colorIndex, sick: open != nil, name: kid.name, status: status,
                          numbers: [(illnesses.count, tr("brought home")), (gotYou, tr("got you")), (dodged, tr("you dodged"))]) {
            editing = .kid(kid)
        }
    }

    private var meCard: some View {
        let logs = model.data.logs
        let daysSick = logs.reduce(0) { $0 + $1.dayCount() }
        let dodged = model.data.kidIllnesses.filter { $0.outcome == .dodged }.count
        return PersonCard(look: model.data.hostLook, sick: model.onSickLeave, name: model.displayName,
                          status: tr("%1$@, level %2$lld", model.displayTitle, model.level.number),
                          numbers: [(logs.count, tr("germs caught")), (daysSick, tr("days sick")), (dodged, tr("germs dodged"))]) {
            editing = .me
        }
    }

    @ViewBuilder
    private var partnerCard: some View {
        if let partner = model.data.partnerName {
            let logs = model.data.logs.filter { $0.sufferer.includesPartner }
            let daysSick = logs.reduce(0) { $0 + $1.dayCount() }
            PersonCard(look: model.data.partnerLook, sick: model.activeLog?.sufferer.includesPartner == true,
                       name: partner, status: tr("Partner"),
                       numbers: [(logs.count, tr("germs caught")), (daysSick, tr("days sick"))]) {
                editing = .partner
            }
        } else {
            Button {
                editing = .partner
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 48, height: 48)
                        .background(palette.surface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Add your partner"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(tr("It opens the couple duel."))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                }
                .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }
}

/// One member of the household: a character, a name, a line about them and up to three numbers.
private struct PersonCard: View {
    let look: Int
    let sick: Bool
    let name: String
    let status: String
    let numbers: [(value: Int, label: String)]
    let edit: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                BuddyView(look: look, sick: sick, size: 64, lively: true, pokes: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(palette.ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: edit) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 40, height: 40)
                        .background(palette.background.opacity(0.62), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(tr("Edit %@", name))
            }
            Rectangle()
                .fill(palette.ink.opacity(0.12))
                .frame(height: 1)
                .padding(.top, 14)
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(numbers.enumerated()), id: \.offset) { item in
                    VStack(alignment: .leading, spacing: 0) {
                        RollingNumber(value: item.element.value)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(palette.ink)
                        Text(item.element.label)
                            .font(.footnote)
                            .foregroundStyle(palette.ink.opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Buddy.tint(look).opacity(palette.isDark ? 0.2 : 0.3),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
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
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        .buttonStyle(PillButtonStyle(kind: .ghost, height: 50))
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
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Save")) {
                        save()
                    }
                    .fontWeight(.semibold)
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
                    Text(tr("Their germs and countdowns are removed too. Your own journal stays."))
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
                BuddyView(look: look, sick: showsSick, size: 104, lively: true)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: look)
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
