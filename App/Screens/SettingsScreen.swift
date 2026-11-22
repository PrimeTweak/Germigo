import StoreKit
import SwiftUI

/// A settings row label.
struct SettingsLabel: View {
    let title: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(title)
            .foregroundStyle(palette.ink)
    }
}

/// The trailing arrow of a row that opens something but is not a navigation link.
struct RowChevron: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
    }
}

/// The gear in the top-right corner of every tab; it opens Settings.
struct SettingsButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel(tr("Settings"))
    }
}

/// Settings, opened from any tab: the pass, the look, sound, notifications, help, data and the rest.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var showTips = false
    @State private var redeeming = false
    @State private var notificationsDenied = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    PassTicket(showPaywall: $showPaywall, showManage: $showManage)
                        .cascadeIn(0)
                    if !model.hasPass {
                        passLinks
                    }
                    SectionHeader(title: tr("Look"))
                    LookCard()
                        .cascadeIn(1)
                    SectionHeader(title: tr("Sound"))
                    soundCard
                        .cascadeIn(2)
                    SectionHeader(title: tr("Notifications"))
                    notificationCard
                        .cascadeIn(3)
                    quietNote
                    SectionHeader(title: tr("Help"))
                    helpCard
                        .cascadeIn(4)
                    SectionHeader(title: tr("Data"))
                    dataCard
                        .cascadeIn(5)
                    SectionHeader(title: tr("About"))
                    aboutCard
                        .cascadeIn(6)
                    SneezyFooter()
                        .padding(.top, 22)
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 28)
            }
            .background(palette.background.ignoresSafeArea())
            .tint(palette.accent)
            .navigationTitle(tr("Settings"))
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showTips) {
                TipSheet()
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .offerCodeRedemption(isPresented: $redeeming) { _ in
                Task {
                    await purchases.refreshEntitlements()
                }
            }
            .alert(tr("Restore purchases"), isPresented: restoreBinding) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .onChange(of: model.data.settings.checkInsOn) { _, isOn in
                if isOn { askForReminders() }
            }
            .onChange(of: model.data.settings.lessonAlertsOn) { _, isOn in
                if isOn { askForReminders() }
            }
            .onChange(of: model.data.settings.crewAlertsOn) { _, isOn in
                if isOn { askForReminders() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshNotificationStatus() }
            }
            .task {
                notificationsDenied = await NotificationManager.isDenied()
            }
        }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { shown in
            if !shown { restoreMessage = nil }
        })
    }

    private func refreshNotificationStatus() {
        Task {
            notificationsDenied = await NotificationManager.isDenied()
        }
    }

    private func askForReminders() {
        Task {
            await model.enableReminders()
            notificationsDenied = await NotificationManager.isDenied()
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            let failure = await purchases.restore()
            isRestoring = false
            if let failure {
                restoreMessage = failure
            } else if model.hasPass {
                restoreMessage = tr("Your Season Pass is active on this phone.")
            } else {
                restoreMessage = tr("No Season Pass was found for this Apple Account.")
            }
        }
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.data.settings[keyPath: keyPath] },
                set: { value in model.updateSettings { $0[keyPath: keyPath] = value } })
    }

    // MARK: - Cards

    private var passLinks: some View {
        HStack(spacing: 24) {
            Button(tr("Restore purchases")) {
                restore()
            }
            .disabled(isRestoring)
            Button(tr("Redeem a code")) {
                redeeming = true
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(palette.accent)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }

    private var soundCard: some View {
        let settings = model.data.settings
        return Toggle(isOn: setting(\.soundsOn)) {
            SettingsRowLabel(symbol: settings.soundsOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                             title: tr("Sounds and haptics"), detail: tr("Sounds stay off from 10 PM to 7 AM"),
                             trigger: settings.soundsOn)
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    /// Under the notifications: the hours when reminders wait, told by the mascot asleep. It is not a setting.
    private var quietNote: some View {
        HStack(spacing: 14) {
            DozingMascot()
            Text(tr("From 10 PM to 7 AM, reminders wait for the morning."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private var notificationCard: some View {
        let settings = model.data.settings
        return VStack(spacing: 0) {
            Toggle(isOn: setting(\.checkInsOn)) {
                SettingsRowLabel(symbol: settings.checkInsOn ? "bell.fill" : "bell.slash.fill", title: tr("Check-ins"),
                                 detail: tr("Window and symptom reminders"), trigger: settings.checkInsOn)
            }
            .frame(minHeight: 54)
            if AppConfig.lessonsURL != nil {
                Divider()
                    .padding(.leading, 44)
                Toggle(isOn: setting(\.lessonAlertsOn)) {
                    SettingsRowLabel(symbol: "graduationcap.fill", title: tr("New lessons"),
                                     detail: tr("When a lesson comes out"), trigger: settings.lessonAlertsOn)
                }
                .frame(minHeight: 54)
            }
            if AppConfig.crewEnabled {
                Divider()
                    .padding(.leading, 44)
                Toggle(isOn: setting(\.crewAlertsOn)) {
                    SettingsRowLabel(symbol: "dot.radiowaves.left.and.right", title: tr("Crew alerts"),
                                     detail: tr("When a germ goes around"), trigger: settings.crewAlertsOn)
                }
                .frame(minHeight: 54)
            }
            if notificationsDenied, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Divider()
                    .padding(.leading, 44)
                Link(destination: url) {
                    SettingsRow(symbol: "bell.slash.fill", title: tr("Turn on in iOS Settings"),
                                detail: tr("Notifications are off for Germily, so no reminder can reach you.")) {
                        RowChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    private var helpCard: some View {
        NavigationLink {
            HelpLinesScreen()
        } label: {
            SettingsRow(symbol: "lifepreserver.fill", title: tr("Help lines"), detail: tr("Emergency and health lines")) {
                RowChevron()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    private var dataCard: some View {
        VStack(spacing: 0) {
            ShareLink(item: JournalBackup(data: model.data), preview: SharePreview(tr("Germily backup"))) {
                SettingsRow(symbol: "archivebox.fill", title: tr("Back up now"), detail: tr("Journal and photos, where you choose")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 44)
            NavigationLink {
                DataScreen()
            } label: {
                SettingsRow(symbol: "lock.shield.fill", title: tr("Data and privacy")) {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                AboutScreen()
            } label: {
                SettingsRow(symbol: "info.circle.fill", title: tr("About Germily")) {
                    HStack(spacing: 8) {
                        Text(verbatim: AppConfig.versionLabel)
                            .font(.callout)
                            .foregroundStyle(palette.inkSecondary)
                        RowChevron()
                    }
                }
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 44)
            Button {
                showTips = true
            } label: {
                SettingsRow(art: "sticker-soup", title: tr("Offer a soup"), detail: tr("A small tip, if Germily made you laugh")) {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            #if GERMILY_SIDELOAD
            Divider()
                .padding(.leading, 44)
            Toggle(isOn: setting(\.sideloadPass)) {
                SettingsRowLabel(symbol: "hammer.fill", title: tr("Pass (test build)"))
            }
            .frame(minHeight: 54)
            #endif
        }
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }
}

// MARK: - Rows

/// The leading part of a settings row: a tile with a symbol or a sticker, a title and a line under it.
private struct SettingsRowLabel: View {
    var symbol: String?
    var art: String?
    let title: String
    var detail: String?
    /// The symbol bounces each time this value changes.
    var trigger = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(palette.ink.opacity(0.07))
                .frame(width: 32, height: 32)
                .overlay {
                    if let art {
                        Image(art)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                    } else if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: trigger)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 8)
    }
}

/// A settings row: its label on the leading side, a control or a chevron on the other.
private struct SettingsRow<Trailing: View>: View {
    let label: SettingsRowLabel
    let trailing: Trailing

    init(symbol: String? = nil, art: String? = nil, title: String, detail: String? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        label = SettingsRowLabel(symbol: symbol, art: art, title: title, detail: detail)
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            label
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

/// A small mascot asleep beside the quiet hours note.
private struct DozingMascot: View {
    var body: some View {
        LivelyCharacter(mood: .resting, touch: nil) {
            Image("mascot-asleep")
                .resizable()
                .scaledToFit()
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
            SnoreView()
                .scaleEffect(0.5)
                .frame(width: 30, height: 30)
                .offset(x: 10, y: -14)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Season Pass ticket

/// The Season Pass as a ticket: an offer before, a holo pass after.
private struct PassTicket: View {
    @Binding var showPaywall: Bool
    @Binding var showManage: Bool
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The ticket's title, following the text size set in iOS.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34

    private let night = Color(hex: Swatch.navy)
    private let frost = Color(hex: Swatch.frost)

    private var active: Bool { model.hasPass }

    private var pitch: String {
        if let partner = model.data.partnerName {
            return tr("%@, every kid, the whole history and photos for the doctor.", partner)
        }
        return tr("Your partner, every kid, the whole history and photos for the doctor.")
    }

    private var planLine: String {
        if purchases.activeProductID == PassProduct.yearlyID { return tr("Yearly plan") }
        if purchases.activeProductID == PassProduct.monthlyID { return tr("Monthly plan") }
        return tr("Test build")
    }

    private var familyShared: Bool {
        purchases.products.first { $0.id == purchases.activeProductID }?.isFamilyShareable ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Germily · Admit one household"))
                        .font(.caption.weight(.bold))
                        .opacity(0.7)
                    Text(tr("Season Pass"))
                        .font(.system(size: titleSize, weight: .bold))
                        .kerning(-0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                faces
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            notches
                .padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 12) {
                Text(active ? planLine : pitch)
                    .font(.subheadline)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if active {
                    activeButtons
                } else {
                    offerButton
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .foregroundStyle(active ? night : frost)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backdrop)
        .overlay {
            if !reduceMotion {
                Shine()
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .animation(Tempo.quick, value: active)
    }

    private var backdrop: LinearGradient {
        if active {
            return LinearGradient(colors: [Color(hex: Swatch.iris), Color(hex: Swatch.wisteria), Color(hex: Swatch.aqua),
                                           Color(hex: Swatch.pinkPale)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color(hex: Swatch.navyRaised), night], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The household on the ticket, each one breathing on its own beat.
    private var faces: some View {
        let kidLook = model.data.kids.first?.colorIndex ?? 0
        return HStack(alignment: .bottom, spacing: -14) {
            BuddyView(look: model.data.partnerLook, size: 46, lively: true)
            BuddyView(look: kidLook, size: 54, lively: true)
            BuddyView(look: model.data.hostLook, size: 46, lively: true)
        }
        .accessibilityHidden(true)
    }

    /// The ticket's tear line, with a notch cut on each side.
    private var notches: some View {
        ZStack {
            TicketDash()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .foregroundStyle((active ? night : frost).opacity(0.3))
                .frame(height: 2)
                .padding(.horizontal, 20)
            HStack {
                Circle().fill(palette.background).frame(width: 22, height: 22).offset(x: -11)
                Spacer()
                Circle().fill(palette.background).frame(width: 22, height: 22).offset(x: 11)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var offerButton: some View {
        Button {
            showPaywall = true
        } label: {
            Text(purchases.trialDays.map { tr("Try %lld days free", $0) } ?? tr("See the Season Pass"))
                .font(.headline)
                .foregroundStyle(night)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(frost, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        if purchases.trialDays != nil, let yearly = purchases.yearly {
            Text(tr("Then %@ a year. Cancel anytime.", yearly.displayPrice))
                .font(.caption)
                .opacity(0.65)
                .frame(maxWidth: .infinity)
        }
    }

    private var activeButtons: some View {
        HStack(spacing: 8) {
            if purchases.storePass {
                Button {
                    showManage = true
                } label: {
                    Text(tr("Manage"))
                        .font(.headline)
                        .foregroundStyle(frost)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(night, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            if familyShared {
                Label(tr("Family Sharing included"), systemImage: "person.2.fill")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.5), in: Capsule())
            }
        }
    }
}

/// A band of light that crosses the ticket once when it appears.
private struct Shine: View {
    @State private var crossed = false

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, Color.white.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.45)
                .rotationEffect(.degrees(18))
                .offset(x: crossed ? proxy.size.width * 1.1 : -proxy.size.width * 0.6)
        }
        .onAppear {
            crossed = false
            withAnimation(Tempo.reveal.delay(0.4)) {
                crossed = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Look

/// The look in three choices: the app icon and the theme each open their page, light or dark is picked in place.
private struct LookCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var icon = AppIconOption.germily

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                AppIconScreen()
            } label: {
                row(tr("App icon"), value: icon.title) {
                    Image(icon.previewAsset)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 44)
            NavigationLink {
                ThemeScreen()
            } label: {
                row(tr("Theme"), value: model.data.settings.theme.title) {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(palette.ink.opacity(0.07))
                        .overlay {
                            Circle()
                                .fill(palette.accent)
                                .frame(width: 16, height: 16)
                        }
                }
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 44)
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("Appearance"))
                    .font(.body)
                    .foregroundStyle(palette.ink)
                Picker(tr("Appearance"), selection: appearance) {
                    Text(tr("Automatic")).tag(AppearanceMode.system)
                    Text(tr("Light")).tag(AppearanceMode.light)
                    Text(tr("Dark")).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
        .onAppear {
            icon = AppIconManager.current
        }
    }

    private var appearance: Binding<AppearanceMode> {
        Binding(get: { model.data.settings.appearance },
                set: { value in model.updateSettings { $0.appearance = value } })
    }

    /// A row that opens a page: a small picture of the current choice, the title, its name and a chevron.
    private func row<Picture: View>(_ title: String, value: String, @ViewBuilder picture: () -> Picture) -> some View {
        HStack(spacing: 12) {
            picture()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
                .foregroundStyle(palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(.callout)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
            RowChevron()
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

// MARK: - Footer

/// Where the mascot is in its sneeze: a breath in, the sneeze, the landing.
private struct SneezePose {
    var stretchX = 1.0
    var stretchY = 1.0
    var tilt = 0.0
    var lift = 0.0

    static func at(_ time: Double) -> SneezePose {
        var pose = SneezePose()
        switch time {
        case 0..<0.35:
            let part = time / 0.35
            pose.stretchX = 1 + 0.08 * part
            pose.stretchY = 1 - 0.1 * part
            pose.tilt = 4 * part
        case 0.35..<0.55:
            let part = (time - 0.35) / 0.2
            pose.stretchX = 1.08 - 0.18 * part
            pose.stretchY = 0.9 + 0.22 * part
            pose.tilt = 4 - 12 * part
            pose.lift = -18 * sin(part * .pi / 2)
        case 0.55..<0.95:
            let rest = 1 - (time - 0.55) / 0.4
            pose.stretchX = 1 - 0.1 * rest
            pose.stretchY = 1 + 0.12 * rest
            pose.tilt = -8 * rest
            pose.lift = -18 * rest * rest
        default:
            break
        }
        return pose
    }
}

/// The page's last line: the mascot asleep until tapped, then a sneeze and a burst of tissues.
private struct SneezyFooter: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sneezedAt = Date.distantPast
    @State private var running = false

    private static let length = 2.2
    private static let flights: [(dx: Double, dy: Double, spin: Double)] = [(-90, -50, -160), (80, -64, 140), (-60, 12, 90),
                                                                           (96, 4, -120)]

    var body: some View {
        VStack(spacing: 2) {
            Button(action: sneeze) {
                TimelineView(.animation(minimumInterval: nil, paused: !running)) { timeline in
                    scene(timeline.date.timeIntervalSince(sneezedAt))
                }
                .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("Wake the germ"))
            Text(verbatim: "Germily " + AppConfig.versionLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 6)
            Text(tr("Tap the germ. Gently."))
                .font(.footnote)
                .foregroundStyle(palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sneeze() {
        guard !running else { return }
        sneezedAt = Date()
        running = true
        Haptics.tap()
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            Haptics.thud()
            try? await Task.sleep(for: .milliseconds(2050))
            running = false
        }
    }

    private func scene(_ time: Double) -> some View {
        let awake = time >= 0 && time < Self.length
        let pose = reduceMotion ? SneezePose() : SneezePose.at(time)
        return ZStack {
            Image(awake ? "mascot-awake" : "mascot-asleep")
                .resizable()
                .scaledToFit()
                .scaleEffect(x: pose.stretchX, y: pose.stretchY, anchor: .bottom)
                .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                .offset(y: pose.lift)
            if !awake {
                SnoreView()
                    .scaleEffect(0.6)
                    .offset(x: 46, y: -28)
            }
            if !reduceMotion {
                tissues(time)
            }
            Text(tr("Achoo!"))
                .font(.headline.weight(.heavy))
                .foregroundStyle(palette.accent)
                .fixedSize()
                .scaleEffect(reduceMotion ? 1 : achooScale(time))
                .opacity(achooOpacity(time))
                .offset(x: 72, y: -26)
                .accessibilityHidden(true)
        }
    }

    private func tissues(_ time: Double) -> some View {
        let part = (time - 0.4) / 1.0
        return ForEach(0..<Self.flights.count, id: \.self) { index in
            let flight = Self.flights[index]
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(palette.ink.opacity(0.15), lineWidth: 1)
                }
                .frame(width: 14, height: 11)
                .rotationEffect(.degrees(flight.spin * max(0, part)))
                .offset(x: flight.dx * part, y: flight.dy * part + 60 * part * part)
                .opacity(part > 0 && part < 1 ? 1 - part * part : 0)
        }
    }

    private func achooScale(_ time: Double) -> Double {
        if time < 0.4 { return 0.6 }
        if time < 0.55 { return 0.6 + 0.5 * (time - 0.4) / 0.15 }
        if time < 0.7 { return 1.1 - 0.1 * (time - 0.55) / 0.15 }
        return 1
    }

    private func achooOpacity(_ time: Double) -> Double {
        if time < 0.4 || time >= 1.95 { return 0 }
        if time < 1.7 { return 1 }
        return 1 - (time - 1.7) / 0.25
    }
}

// MARK: - Tip jar

/// The tip jar: three soups to offer, and a warm thank-you.
struct TipSheet: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var thankedAt: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    SteamingSoup(thankedAt: thankedAt)
                        .padding(.top, 8)
                    Text(thankedAt == nil ? tr("Offer a soup") : tr("Slurp! Thank you."))
                        .font(.title.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .contentTransition(.opacity)
                    Text(thankedAt == nil ? tr("No ads and no data sold, ever. A soup now and then keeps it that way.")
                                          : tr("The germs are furious. Germily is warm and fed."))
                        .font(.callout)
                        .foregroundStyle(palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if thankedAt != nil {
                        Button(tr("Done")) {
                            dismiss()
                        }
                        .buttonStyle(PillButtonStyle(kind: .ink))
                        .padding(.top, 8)
                    } else if purchases.tips.isEmpty {
                        unavailable
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(purchases.tips.enumerated()), id: \.element.id) { item in
                                tipRow(item.element, rank: item.offset)
                                    .cascadeIn(item.offset)
                            }
                        }
                        .padding(.top, 8)
                        Text(tr("A tip is a one-time purchase. It unlocks nothing; it just feels nice."))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 24)
            }
            .overlay {
                if let thankedAt {
                    ConfettiView(start: thankedAt)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Close"))
                }
            }
            .alert(tr("Purchase"), isPresented: errorBinding) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(purchases.lastError ?? "")
            }
            .alert(tr("Waiting for approval"), isPresented: pendingBinding) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(tr("Your soup needs an approval. It goes through by itself once it's approved."))
            }
        }
        .tint(palette.accent)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchases.lastError != nil }, set: { if !$0 { purchases.lastError = nil } })
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { purchases.pendingNotice }, set: { purchases.pendingNotice = $0 })
    }

    @ViewBuilder
    private var unavailable: some View {
        if purchases.isLoading {
            ProgressView()
                .padding(.top, 12)
        } else {
            VStack(spacing: 12) {
                Text(tr("The tip jar isn't open right now. Try again later."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                Button(tr("Try again")) {
                    Task {
                        await purchases.loadProducts()
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
            }
            .padding(.top, 8)
        }
    }

    private func tipTitle(_ rank: Int) -> String {
        switch rank {
        case 0: return tr("A cup of broth")
        case 1: return tr("A bowl of chicken noodle")
        default: return tr("A pot for the whole daycare")
        }
    }

    private func tipLine(_ rank: Int) -> String {
        switch rank {
        case 0: return tr("Warms up one sniffle")
        case 1: return tr("With extra noodles")
        default: return tr("Enough for every runny nose")
        }
    }

    private func tipRow(_ product: Product, rank: Int) -> some View {
        let side = 34 + CGFloat(min(rank, 2)) * 9
        return Button {
            buy(product)
        } label: {
            HStack(spacing: 14) {
                Image("sticker-soup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .frame(width: 60, height: 60)
                    .background(Color(hex: Swatch.peach).opacity(0.35), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tipTitle(rank))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(tipLine(rank))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(palette.accent, in: Capsule())
            }
            .germilyCard(padding: 12)
        }
        .buttonStyle(PressableStyle())
        .disabled(purchases.isPurchasing)
    }

    private func buy(_ product: Product) {
        Task {
            guard await purchases.tip(product) else { return }
            Haptics.success()
            withAnimation(Tempo.pop) {
                thankedAt = Date()
            }
        }
    }
}

/// A bowl of soup with steam rising; a heart pops out of it once the soup is offered.
private struct SteamingSoup: View {
    let thankedAt: Date?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    steam(timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            LivelyCharacter(mood: .resting) {
                Image("sticker-soup")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 132, height: 132)
            .padding(.top, 34)
            if thankedAt != nil {
                Image("sticker-heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .offset(x: 52, y: 6)
                    .motionTransition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(width: 180, height: 170)
        .accessibilityHidden(true)
    }

    private func steam(_ time: Double) -> some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { index in
                let phase = (time / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                Capsule()
                    .fill(palette.ink.opacity(0.16 * min(1, min(phase, 1 - phase) * 3)))
                    .frame(width: 7, height: 26)
                    .offset(x: 3 * sin(phase * 2 * .pi), y: 34 - 30 * phase)
            }
        }
        .frame(height: 60)
    }
}
