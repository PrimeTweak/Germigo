import SwiftUI

struct AlbumScreen: View {
    private enum Segment: Hashable {
        case germs
        case badges
        case kids
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var segment = Segment.germs
    @State private var lockedGerm: Germ?
    @State private var guideRequested = false
    @State private var showGuide = false
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cardWidth = max(96, (proxy.size.width - 40 - 24) / 3)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tr("%1$lld of %2$lld germs caught", model.caughtGermIDs.count, model.catalog.germs.count))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .padding(.horizontal, 4)
                        Picker(tr("Section"), selection: $segment) {
                            Text(tr("Germs")).tag(Segment.germs)
                            Text(tr("Badges")).tag(Segment.badges)
                            Text(tr("Kids' germs")).tag(Segment.kids)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        switch segment {
                        case .germs:
                            grid(cardWidth: cardWidth)
                        case .badges:
                            NavigationLink {
                                SkillTreeScreen()
                            } label: {
                                ValueRow(symbol: "point.3.connected.trianglepath.dotted", tint: palette.lilac,
                                         title: tr("Skill Tree"), value: model.displayTitle)
                                    .padding(.horizontal, 16)
                                    .petriCard(padding: 0)
                            }
                            .buttonStyle(.plain)
                            BadgesGrid()
                        case .kids:
                            KidsGermsView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Album"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FieldGuideScreen()
                    } label: {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel(tr("Field Guide"))
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
                    .navigationTransition(.zoom(sourceID: germ.id, in: zoom))
            }
            .navigationDestination(isPresented: $showGuide) {
                FieldGuideScreen()
            }
            .sheet(item: $lockedGerm, onDismiss: openGuideIfRequested) { germ in
                LockedCardSheet(germ: germ) {
                    guideRequested = true
                }
                .presentationDetents([.medium])
            }
        }
    }

    /// Pushes the Field Guide once the locked-card sheet is gone.
    private func openGuideIfRequested() {
        guard guideRequested else { return }
        guideRequested = false
        showGuide = true
    }

    private func grid(cardWidth: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(model.catalog.germs) { germ in
                let finish = model.cardFinish(for: germ)
                if finish == .locked {
                    Button {
                        lockedGerm = germ
                    } label: {
                        GermCardView(germ: germ, width: cardWidth, finish: .locked)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: germ) {
                        GermCardView(germ: germ, width: cardWidth, finish: finish, count: model.count(of: germ.id))
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: germ.id, in: zoom)
                }
            }
        }
    }
}

/// Explains a locked card without spoiling which germ it is.
private struct LockedCardSheet: View {
    let germ: Germ
    let onOpenGuide: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            GermCardView(germ: germ, width: 132, finish: .locked)
                .padding(.top, 28)
            Text(tr("Card %@ is still out there", germ.numberLabel))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
            Text(tr("Rarity: %@. Catch it to reveal the card. The health notes for every germ are always open in the Field Guide.",
                    germ.rarity.label))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button(tr("Open the Field Guide")) {
                    onOpenGuide()
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                Button(tr("Got it")) {
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}

private struct BadgesGrid: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(BadgeCatalog.all) { badge in
                let earned = model.hasBadge(badge.id)
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: earned ? badge.symbol : "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(earned ? Color.white : palette.inkTertiary)
                        .frame(width: 46, height: 46)
                        .background(earned ? Color(hex: badge.tint) : palette.surfaceAlt, in: Circle())
                    Text(badge.title)
                        .font(.headline)
                        .foregroundStyle(earned ? palette.ink : palette.inkSecondary)
                    Text(badge.detail)
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                .petriCard(radius: 22, padding: 14)
                .accessibilityElement(children: .combine)
                .accessibilityValue(earned ? tr("Earned") : tr("Locked"))
            }
        }
    }
}

/// What each kid has had, which also drives the incubation countdowns.
private struct KidsGermsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showSheet = false
    @State private var pendingDelete: KidIllness?

    private var illnesses: [KidIllness] {
        model.data.kidIllnesses.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showSheet = true
            } label: {
                Label(tr("Add a kid's germ"), systemImage: "plus")
            }
            .buttonStyle(PillButtonStyle(kind: .ink, height: 50))
            if illnesses.isEmpty {
                Text(tr("When a kid gets sick, add it here. Petri starts your incubation countdown and remembers who brought what home."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
            }
            ForEach(illnesses) { illness in
                row(illness)
            }
        }
        .sheet(isPresented: $showSheet) {
            KidIllnessSheet()
        }
        .confirmationDialog(tr("Delete this entry?"), isPresented: deleteBinding, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) {
                if let illness = pendingDelete { model.deleteKidIllness(illness.id) }
                pendingDelete = nil
            }
            Button(tr("Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(tr("Its countdown and reminders go with it."))
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { shown in
            if !shown { pendingDelete = nil }
        })
    }

    @ViewBuilder
    private func row(_ illness: KidIllness) -> some View {
        if let germ = model.catalog.germ(illness.germID) {
            let kid = model.kid(illness.kidID)
            HStack(spacing: 12) {
                NavigationLink {
                    GermDetailScreen(germ: germ)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(name: kid?.name ?? "?", gradient: AvatarColors.gradient(kid?.colorIndex ?? 0), size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((kid?.name ?? tr("Your kid")) + " · " + germ.illness.value)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                            Text(illness.startedAt.formatted(date: .abbreviated, time: .omitted) + " · " + outcomeLabel(illness.outcome))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Menu {
                    Button(role: .destructive) {
                        pendingDelete = illness
                    } label: {
                        Label(tr("Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(palette.inkSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(tr("More"))
            }
            .petriCard(radius: 22, padding: 12)
        }
    }

    private func outcomeLabel(_ outcome: ExposureOutcome) -> String {
        switch outcome {
        case .open: return tr("You're still clear")
        case .caught: return tr("You caught it")
        case .dodged: return tr("You dodged it")
        case .expired: return tr("Window passed")
        }
    }
}

/// Adds a kid's illness and starts the parent's exposure countdown.
struct KidIllnessSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var kidID: UUID?
    @State private var germID: String?
    @State private var startedAt = Date()
    @State private var watch = true
    @State private var newKidName = ""
    @State private var saved = false

    /// False for the germs that have no known incubation window, so nothing to watch.
    private var hasWindow: Bool {
        guard let germID, let germ = model.catalog.germ(germID) else { return true }
        return germ.incubationMinHours != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.data.kids.isEmpty {
                        TextField(tr("Kid's name"), text: $newKidName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 16) {
                                ForEach(model.data.kids) { kid in
                                    Button {
                                        kidID = kid.id
                                    } label: {
                                        VStack(spacing: 6) {
                                            AvatarView(name: kid.name, gradient: AvatarColors.gradient(kid.colorIndex), size: 54)
                                                .padding(4)
                                                .overlay {
                                                    Circle().strokeBorder(kidID == kid.id ? palette.ink : Color.clear, lineWidth: 2.5)
                                                }
                                            Text(kid.name)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(palette.ink)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                    Text(tr("What do they have?").uppercased())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    GermPicker(selection: $germID)
                    VStack(spacing: 0) {
                        DatePicker(tr("Since"), selection: $startedAt, in: AppModel.earliestNewEntry...Date(),
                                   displayedComponents: [.date, .hourAndMinute])
                            .frame(minHeight: 54)
                        if hasWindow {
                            Divider()
                            Toggle(tr("Watch my window"), isOn: $watch)
                                .frame(minHeight: 54)
                        }
                    }
                    .tint(.green)
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 16)
                    .petriCard(padding: 0)
                    Text(hasWindow
                         ? tr("Watching sends a check-in when your window opens and closes. During the last 8 hours of the window, opening Petri also puts the countdown on the Lock Screen.")
                         : tr("No countdown for this one. The Field Notes explain what to watch for."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("A kid is sick"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Add")) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if kidID == nil { kidID = model.data.kids.first?.id }
            }
        }
    }

    private var canSave: Bool {
        guard germID != nil else { return false }
        if model.data.kids.isEmpty {
            return !newKidName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return kidID != nil
    }

    private func save() {
        guard !saved, let germID else { return }
        var target = kidID
        if model.data.kids.isEmpty {
            let kid = Kid(name: newKidName.trimmingCharacters(in: .whitespaces), colorIndex: 0)
            model.saveKid(kid)
            target = kid.id
        }
        guard let target else { return }
        saved = true
        let illness = model.addKidIllness(kidID: target, germID: germID, startedAt: startedAt)
        if watch && hasWindow {
            Task {
                _ = await NotificationManager.requestAuthorization()
                model.setWatching(illness.id, watching: true)
            }
        }
        dismiss()
    }
}
