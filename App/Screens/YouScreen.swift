import SwiftUI

/// The parent's own page: who they are, three numbers, and the doors to everything they earned.
struct YouScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editingPartner = false
    @State private var nameDraft = ""

    private var hasHistory: Bool {
        !model.data.logs.isEmpty || !model.data.kidIllnesses.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    level
                    if hasHistory {
                        numbers
                            .padding(.top, 26)
                    } else {
                        Text(tr("Season %lld starts with your first germ. Nothing yet. Enjoy it while it lasts.", model.season.number))
                            .font(.body)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 26)
                    }
                    doors
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("You"))
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .alert(tr("Partner"), isPresented: $editingPartner) {
                TextField(tr("Name"), text: $nameDraft)
                Button(tr("Save")) {
                    model.setPartnerName(nameDraft)
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Used for the couple duel, the nap coupon and Tag Team. Leave it empty to remove."))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("mascot-awake")
                .resizable()
                .scaledToFit()
                .frame(width: 62, height: 62)
                .offset(y: 7)
                .frame(width: 76, height: 76)
                .background(Color(hex: Swatch.irisSoft).opacity(0.34))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(tr("%1$@, level %2$lld", model.displayTitle, model.level.number))
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var level: some View {
        let level = model.level
        if level.span > 0 {
            ThinGauge(fraction: level.fraction, fill: palette.accent)
                .padding(.top, 18)
            Text(tr("%1$lld of %2$lld points to level %3$lld", level.progress, level.span, level.number + 1))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 8)
        }
    }

    private var numbers: some View {
        let logs = model.data.logs
        let daysSick = logs.reduce(0) { $0 + $1.dayCount() }
        let dodged = model.data.kidIllnesses.filter { $0.outcome == .dodged }.count
        return HStack(alignment: .top, spacing: 0) {
            number(logs.count, tr("germs caught"))
            number(daysSick, tr("days sick"))
            number(dodged, tr("germs dodged"))
        }
    }

    private func number(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: String(value))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var doors: some View {
        let season = model.season
        let earned = BadgeCatalog.all.filter { model.hasBadge($0.id) }.count
        let entries = model.data.logs.count + model.data.kidIllnesses.count
        return VStack(spacing: 0) {
            if let goal = GoalEngine.next(data: model.data, catalog: model.catalog, now: Date()) {
                door(tr("Next up: %@", goal.title), tr("%1$lld of %2$lld", goal.progress, goal.target)) {
                    SkillTreeScreen()
                }
                Divider()
            }
            door(tr("Season %lld", season.number), tr("Week %lld", season.week(for: Date()))) {
                SeasonScreen()
            }
            Divider()
            door(tr("Skill Tree"), model.displayTitle) {
                SkillTreeScreen()
            }
            Divider()
            door(tr("Badges"), tr("%1$lld of %2$lld", earned, BadgeCatalog.all.count)) {
                BadgesScreen()
            }
            Divider()
            door(tr("Logbook"), entries == 0 ? tr("Empty") : trCount(entries, one: "%lld entry", other: "%lld entries")) {
                LogbookScreen()
            }
            Divider()
            duelDoor(season)
            if hasHistory {
                Divider()
                door(tr("For the doctor"), nil) {
                    DoctorSummaryScreen()
                }
            }
        }
        .padding(.horizontal, 18)
        .petriCard(padding: 0)
    }

    private func door<Destination: View>(_ title: String, _ value: String?,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            ValueRow(title: title, value: value)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func duelDoor(_ season: Season) -> some View {
        if let partner = model.data.partnerName {
            let stats = DuelEngine.stats(data: model.data, season: season, now: Date())
            door(tr("Couple duel"), tr("You %1$lld, %2$@ %3$lld", stats.me.germs, partner, stats.partner.germs)) {
                SeasonScreen()
            }
        } else {
            Button {
                nameDraft = ""
                editingPartner = true
            } label: {
                ValueRow(title: tr("Couple duel"), value: tr("Add your partner"))
            }
            .buttonStyle(.plain)
        }
    }
}
