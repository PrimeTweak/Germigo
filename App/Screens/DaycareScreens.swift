import SwiftUI
import VisionKit

/// Where a daycare row of the Crew tab leads.
enum DaycareRoute: Hashable {
    case daycare(String)
    case notice(String)
    case director
}

/// The daycare's tile: a little house on green.
struct DaycareBadge: View {
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "house.fill")
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(hex: Swatch.green), Color(hex: Swatch.greenInk)],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// How notices and groups read on screen.
enum DaycareText {
    /// Short form, for rows: "Stomach bug in Toddlers".
    static func headline(_ notice: DaycareNotice, germ: Germ, groups: [DaycareGroup]) -> String {
        if let group = groups.first(where: { $0.id == notice.groupID }) {
            return tr("%1$@ in %2$@", germ.illness.value, group.name)
        }
        return tr("%@ at the daycare", germ.illness.value)
    }

    /// Long form, for the notice itself: "Stomach bug in the Toddlers group".
    static func title(_ notice: DaycareNotice, germ: Germ, groups: [DaycareGroup]) -> String {
        if let group = groups.first(where: { $0.id == notice.groupID }) {
            return tr("%1$@ in the %2$@ group", germ.illness.value, group.name)
        }
        return tr("%@ at the daycare", germ.illness.value)
    }

    /// Director's form: "Stomach bug · Toddlers".
    static func sent(_ notice: DaycareNotice, germ: Germ, groups: [DaycareGroup]) -> String {
        let scope = groups.first(where: { $0.id == notice.groupID })?.name ?? tr("Whole daycare")
        return germ.illness.value + " · " + scope
    }

    static func when(_ notice: DaycareNotice) -> String {
        let time = notice.date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(notice.date) { return tr("Today, %@", time) }
        if calendar.isDateInYesterday(notice.date) { return tr("Yesterday, %@", time) }
        return notice.date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func groupName(_ id: String?, in groups: [DaycareGroup]) -> String {
        groups.first(where: { $0.id == id })?.name ?? tr("Whole daycare")
    }
}

/// The top of the Crew tab: the daycares this family follows and the one this phone runs.
struct DaycareSection: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var joining = false
    @State private var settingUp = false

    private var hasAny: Bool { !daycare.memberships.isEmpty || daycare.director != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Daycare"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Spacer()
                if hasAny {
                    Menu {
                        Button(tr("Join a daycare"), systemImage: "qrcode.viewfinder") {
                            joining = true
                        }
                        if daycare.director == nil {
                            Button(tr("I run a daycare"), systemImage: "house") {
                                settingUp = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    .accessibilityLabel(tr("Add a daycare"))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            ForEach(daycare.memberships) { membership in
                NavigationLink(value: DaycareRoute.daycare(membership.id)) {
                    MembershipCard(membership: membership)
                }
                .buttonStyle(PressableStyle())
            }
            if let state = daycare.director {
                NavigationLink(value: DaycareRoute.director) {
                    directorCard(state)
                }
                .buttonStyle(PressableStyle())
            }
            if !hasAny {
                invitation
            }
        }
        .sheet(isPresented: $joining) {
            JoinDaycareSheet()
        }
        .sheet(isPresented: $settingUp) {
            DaycareSetupSheet()
        }
    }

    private func directorCard(_ state: DirectorState) -> some View {
        HStack(spacing: 12) {
            DaycareBadge()
            VStack(alignment: .leading, spacing: 2) {
                Text(state.daycare.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(tr("Daycare mode") + " · " + trCount(state.daycare.families, one: "%lld family", other: "%lld families"))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.inkTertiary)
        }
        .germigoCard(padding: 12)
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                DaycareBadge()
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Daycare notices"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("Your daycare tells you when an illness is going around in your child's group. Free for families and daycares."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Button(tr("Join a daycare")) {
                    joining = true
                }
                .buttonStyle(PillButtonStyle(kind: .ink, height: 44))
                Button(tr("I run a daycare")) {
                    settingUp = true
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 44))
            }
        }
        .germigoCard(padding: 14)
    }
}

/// A followed daycare, with its latest notice.
private struct MembershipCard: View {
    let membership: DaycareStore.Membership
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                DaycareBadge()
                VStack(alignment: .leading, spacing: 2) {
                    Text(membership.feed.daycare.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(KidGroups.line(membership, kids: model.data.kids))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
            }
            if let notice = daycare.latest(in: membership), let germ = model.catalog.germ(notice.germID) {
                HStack(spacing: 10) {
                    GermImage(germ: germ, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(DaycareText.headline(notice, germ: germ, groups: membership.feed.daycare.groups))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Text(DaycareText.when(notice) + " · " + tr("from the daycare"))
                            .font(.caption)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    if daycare.isUnread(notice) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 9, height: 9)
                            .accessibilityLabel(tr("New"))
                    }
                }
                .padding(10)
                .background(germ.lightTint.opacity(palette.isDark ? 0.18 : 0.32),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .germigoCard(padding: 12)
    }
}

/// Which kid is in which group, as one line.
enum KidGroups {
    static func line(_ membership: DaycareStore.Membership, kids: [Kid]) -> String {
        let groups = membership.feed.daycare.groups
        let parts = membership.kidGroups.compactMap { key, group -> (String, String)? in
            let place = DaycareText.groupName(group.isEmpty ? nil : group, in: groups)
            if key == DaycareStore.householdKey { return ("", place) }
            guard let kid = kids.first(where: { $0.id.uuidString == key }) else { return nil }
            return (kid.name, place)
        }
        .sorted { $0.0 < $1.0 }
        if parts.isEmpty { return tr("Whole daycare") }
        return parts.map { $0.0.isEmpty ? $0.1 : $0.0 + " · " + $0.1 }.joined(separator: ", ")
    }
}

/// One notice in a list: the germ, what and when, and a trailing detail.
struct NoticeRow: View {
    let notice: DaycareNotice
    let germ: Germ
    let title: String
    var trailing: String?
    var unread = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            GermImage(germ: germ, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                Text(DaycareText.when(notice))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            if unread {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(tr("New"))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// A followed daycare: its notices, the kids' groups, and leaving.
struct DaycareScreen: View {
    let id: String
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmLeave = false

    var body: some View {
        Group {
            if let membership = daycare.membership(id) {
                content(membership)
            } else {
                ContentUnavailableView(tr("This daycare is no longer on Germigo."), systemImage: "house")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CharacterWash(tint: TabWash.crew))
        .navigationTitle(daycare.membership(id)?.feed.daycare.name ?? tr("Daycare"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ membership: DaycareStore.Membership) -> some View {
        let info = membership.feed.daycare
        let notices = membership.feed.notices.sorted { $0.at > $1.at }
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    DaycareBadge(size: 64)
                    Text(info.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                    if let families = info.families {
                        Text(trCount(families, one: "%lld family", other: "%lld families") + " · "
                             + trCount(info.groups.count, one: "%lld group", other: "%lld groups"))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                SectionHeader(title: tr("Notices"))
                if notices.isEmpty {
                    Text(tr("No notices lately. Good news."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .germigoCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(notices.enumerated()), id: \.element.id) { item in
                            if item.offset > 0 {
                                Divider()
                            }
                            if let germ = model.catalog.germ(item.element.germID) {
                                NavigationLink(value: DaycareRoute.notice(item.element.id)) {
                                    NoticeRow(notice: item.element, germ: germ,
                                              title: DaycareText.headline(item.element, germ: germ, groups: info.groups),
                                              unread: daycare.isUnread(item.element))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .germigoCard(padding: 0)
                }
                SectionHeader(title: tr("Groups"))
                VStack(alignment: .leading, spacing: 12) {
                    Text(KidGroups.line(membership, kids: model.data.kids))
                        .font(.callout)
                        .foregroundStyle(palette.ink)
                    Button(tr("Change groups")) {
                        editing = true
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 44))
                }
                .germigoCard()
                Button(tr("Leave this daycare")) {
                    confirmLeave = true
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                .disabled(daycare.isLoading)
                if let message = daycare.errorMessage {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 4)
                }
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .refreshable {
            await daycare.refresh()
        }
        .sheet(isPresented: $editing) {
            JoinDaycareSheet(editing: membership)
        }
        .confirmationDialog(tr("Leave this daycare?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(tr("Leave"), role: .destructive) {
                Task {
                    if await daycare.leave(membership) { dismiss() }
                }
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("Its notices stop and your subscription is deleted from the server."))
        }
    }

    private var footnote: String {
        var text = tr("The daycare never sees who joined, only how many families each group has. Report a notice from its menu.")
        if daycare.isDemo {
            text = tr("A sample daycare for this test build. Nothing leaves this phone.") + " " + text
        }
        return text
    }
}

/// One notice: the illness, the group, the daycare's note, what to watch for.
struct NoticeScreen: View {
    let id: String
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReport = false
    @State private var reported = false

    var body: some View {
        Group {
            if let found = daycare.notice(id), let germ = model.catalog.germ(found.notice.germID) {
                content(found.notice, membership: found.membership, germ: germ)
            } else if daycare.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(tr("This notice is gone."), systemImage: "bell.slash")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CharacterWash(tint: TabWash.crew))
        .navigationTitle(tr("Notice"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if daycare.notice(id) != nil {
                    Menu {
                        Button(tr("Report this notice"), systemImage: "flag", role: .destructive) {
                            confirmReport = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(tr("More"))
                }
            }
        }
        .confirmationDialog(tr("Report this notice?"), isPresented: $confirmReport, titleVisibility: .visible) {
            Button(tr("Report"), role: .destructive) {
                guard let found = daycare.notice(id) else { return }
                Task {
                    reported = await daycare.report(found.notice, in: found.membership)
                }
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("It disappears from your phone, and the report is reviewed within 24 hours."))
        }
        .alert(tr("Report sent"), isPresented: $reported) {
            Button(tr("OK"), role: .cancel) {
                dismiss()
            }
        } message: {
            Text(tr("Thanks. Every report is reviewed within 24 hours."))
        }
    }

    private func content(_ notice: DaycareNotice, membership: DaycareStore.Membership, germ: Germ) -> some View {
        let groups = membership.feed.daycare.groups
        let kids = daycare.kidIDs(for: notice, in: membership).compactMap { id in model.data.kids.first { $0.id == id } }
            .sorted { $0.name < $1.name }
        let names = kids.map { $0.name }.formatted(.list(type: .and))
        let watching = !kids.isEmpty && kids.allSatisfy { daycare.isWatching(notice, kidID: $0.id) }
        let reference = germ.kidReference ?? germ.sources.first
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(germ.lightTint.opacity(palette.isDark ? 0.22 : 0.45))
                    GermImage(germ: germ, size: 116)
                }
                .frame(height: 170)
                VStack(alignment: .leading, spacing: 6) {
                    Text(DaycareText.title(notice, germ: germ, groups: groups))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                    HStack(spacing: 6) {
                        DaycareBadge(size: 18)
                        Text(membership.feed.daycare.name + " · " + DaycareText.when(notice))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
                if !notice.note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("From the daycare"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                        Text(notice.note)
                            .font(.callout)
                            .foregroundStyle(palette.ink)
                            .textSelection(.enabled)
                    }
                    .germigoCard()
                }
                if !germ.symptoms.isEmpty {
                    Text(tr("What to watch for"))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    ChipRows {
                        ForEach(Array(germ.symptoms.prefix(6).enumerated()), id: \.offset) { item in
                            Text(item.element.text.value)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(palette.surface, in: Capsule())
                        }
                    }
                }
                HStack(spacing: 10) {
                    if !kids.isEmpty {
                        Button {
                            daycare.toggleWatch(notice, kids: kids, germ: germ)
                            if !watching {
                                Task {
                                    _ = await NotificationManager.ensureAuthorization()
                                }
                            }
                        } label: {
                            Label(watching ? tr("Watching %@", names) : tr("Watch %@", names),
                                  systemImage: watching ? "eye.fill" : "eye")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .buttonStyle(PillButtonStyle(kind: watching ? .ghost : .ink, height: 50))
                    }
                    if let reference, let url = URL(string: reference.url) {
                        Link(destination: url) {
                            Label(tr("Official info"), systemImage: "info.circle.fill")
                        }
                        .buttonStyle(PillButtonStyle(kind: .ghost, height: 50))
                    }
                }
                Text(footnote(kids: kids, names: names, notice: notice, germ: germ))
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .onAppear {
            daycare.markRead(notice)
        }
    }

    private func footnote(kids: [Kid], names: String, notice: DaycareNotice, germ: Germ) -> String {
        guard !kids.isEmpty else { return HealthNotice.text }
        let due = NotificationManager.daycareWatchDate(noticeDate: notice.date, germ: germ)
        return tr("Germigo asks %1$@ whether %2$@ caught it. No diagnosis, just a reminder.",
                  due.formatted(.relative(presentation: .named)), names) + " " + HealthNotice.text
    }
}

/// Joins a daycare with its code, or changes the kids' groups.
struct JoinDaycareSheet: View {
    var editing: DaycareStore.Membership?
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var found: DaycareInfo?
    /// Kid key to group ID; an empty group ID means the whole daycare only.
    @State private var choices: [String: String] = [:]
    /// Kids who don't go to this daycare.
    @State private var absent: Set<String> = []
    @State private var scanning = false
    @State private var searching = false
    @State private var submitting = false

    private var info: DaycareInfo? { editing?.feed.daycare ?? found }

    private var keys: [String] {
        model.data.kids.isEmpty ? [DaycareStore.householdKey] : model.data.kids.map { $0.id.uuidString }
    }

    private var canSubmit: Bool {
        info != nil && !submitting && keys.allSatisfy { choices[$0] != nil || absent.contains($0) }
            && keys.contains { choices[$0] != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if editing == nil {
                        codeField
                    }
                    if let info {
                        foundCard(info)
                        ForEach(keys, id: \.self) { key in
                            picker(for: key, groups: info.groups)
                        }
                    } else if searching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if DaycareCode.extract(code) != nil, let message = daycare.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                    if info != nil, let message = daycare.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                    Text(tr("You get the daycare's notices for these groups and for the whole daycare. Nothing about your family is sent: no names, no photos, no journal."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? tr("Join a daycare") : tr("Change groups"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if submitting {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityLabel(editing == nil ? tr("Join") : tr("Save"))
                }
            }
            .task(id: code) {
                await search()
            }
            .sheet(isPresented: $scanning) {
                ScannerSheet { scanned in
                    code = DaycareCode.display(scanned)
                    scanning = false
                }
            }
            .onAppear {
                daycare.errorMessage = nil
                if let editing {
                    choices = editing.kidGroups
                    absent = Set(keys.filter { editing.kidGroups[$0] == nil })
                }
            }
        }
        .tint(palette.ink)
    }

    private var codeField: some View {
        HStack(spacing: 10) {
            TextField(tr("Daycare code"), text: $code)
                .font(.title3.monospaced().weight(.bold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(palette.ink)
            if ScannerSheet.isAvailable {
                Button {
                    scanning = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3)
                        .foregroundStyle(palette.ink)
                }
                .accessibilityLabel(tr("Scan the daycare's code"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func foundCard(_ info: DaycareInfo) -> some View {
        HStack(spacing: 12) {
            DaycareBadge()
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(details(info))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: Swatch.green))
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: Swatch.green), lineWidth: 1.5)
        }
    }

    private func details(_ info: DaycareInfo) -> String {
        let groups = trCount(info.groups.count, one: "%lld group", other: "%lld groups")
        guard let families = info.families else { return groups }
        return groups + " · " + trCount(families, one: "%lld family", other: "%lld families")
    }

    private func picker(for key: String, groups: [DaycareGroup]) -> some View {
        let kid = model.data.kids.first { $0.id.uuidString == key }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let kid {
                    BuddyView(look: kid.colorIndex, size: 28)
                    Text(tr("%@'s group", kid.name))
                } else {
                    Text(tr("Your group"))
                }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(palette.ink)
            ChipRows {
                ForEach(groups) { group in
                    chip(group.name, selected: choices[key] == group.id) {
                        choices[key] = group.id
                        absent.remove(key)
                    }
                }
                chip(tr("Whole daycare only"), selected: choices[key] == "") {
                    choices[key] = ""
                    absent.remove(key)
                }
                if keys.count > 1 {
                    chip(tr("Not at this daycare"), selected: absent.contains(key)) {
                        choices[key] = nil
                        absent.insert(key)
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) {
                action()
            }
        } label: {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(selected ? palette.background : palette.ink)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func search() async {
        guard editing == nil else { return }
        guard let extracted = DaycareCode.extract(code) else {
            found = nil
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        searching = true
        let result = await daycare.lookup(code: extracted)
        searching = false
        guard !Task.isCancelled else { return }
        found = result
        if let result, result.groups.isEmpty {
            for key in keys where choices[key] == nil && !absent.contains(key) {
                choices[key] = ""
            }
        }
    }

    private func submit() {
        let kidGroups = choices.filter { keys.contains($0.key) && !absent.contains($0.key) }
        submitting = true
        Task {
            let done: Bool
            if let editing {
                done = await daycare.setGroups(editing, kidGroups: kidGroups)
            } else if let extracted = DaycareCode.extract(code) {
                done = await daycare.join(code: extracted, kidGroups: kidGroups)
            } else {
                done = false
            }
            submitting = false
            if done { dismiss() }
        }
    }
}

/// Reads a daycare's QR code with the camera.
struct ScannerSheet: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            CodeScanner(onCode: onCode)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    Text(tr("Point at the daycare's QR code."))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .padding(.bottom, 40)
                }
                .navigationTitle(tr("Scan the code"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Cancel")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct CodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, recognizesMultipleItems: false,
                                                isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        var isDone = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !isDone else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue,
                      let code = DaycareCode.extract(payload) else { continue }
                isDone = true
                dataScanner.stopScanning()
                onCode(code)
                return
            }
        }
    }
}
