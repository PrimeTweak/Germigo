import StoreKit
import SwiftUI

@main
struct GermilyApp: App {
    @State private var model = AppModel.shared
    @State private var purchases = PurchaseManager.shared
    @State private var crew = CrewStore.shared
    @State private var daycare = DaycareStore.shared
    @UIApplicationDelegateAdaptor(PushRegistrar.self) private var pushRegistrar
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.install()
        IntentRelay.handler = { action in
            await AppModel.shared.handle(action)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(purchases)
                .environment(crew)
                .environment(daycare)
                .onOpenURL { url in
                    model.open(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                Task {
                    await crew.refresh()
                }
                Task {
                    await daycare.refresh()
                }
                Task {
                    await model.refreshLessons()
                }
            } else if phase == .background, crew.isMember || AppConfig.lessonsURL != nil {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(AppConfig.refreshTaskID)) {
            await CrewStore.shared.backgroundRefresh()
            await AppModel.shared.refreshLessons()
            BackgroundRefresh.schedule()
        }
    }
}

/// Applies the chosen appearance, then resolves the palette for it.
struct RootView: View {
    @Environment(AppModel.self) private var model

    private var scheme: ColorScheme? {
        switch model.data.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        ThemedRoot()
            .preferredColorScheme(scheme)
    }
}

private struct ThemedRoot: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLock.shared

    var body: some View {
        let palette = Palette.make(theme: model.data.settings.theme, scheme: colorScheme, contrast: contrast)
        Group {
            if model.data.onboardingDone {
                MainTabs()
            } else {
                OnboardingFlow()
            }
        }
        .overlay {
            if lock.isLocked {
                LockScreen()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            lock.sceneChanged(phase, enabled: model.data.settings.appLockOn, palette: palette)
        }
        .environment(\.palette, palette)
        .tint(palette.ink)
        .animation(Tempo.scene, value: model.data.onboardingDone)
        .alert(noticeTitle, isPresented: noticeBinding) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
    }

    private var noticeBinding: Binding<Bool> {
        Binding(get: { model.journalNotice != nil }, set: { shown in
            if !shown { model.journalNotice = nil }
        })
    }

    private var noticeTitle: String {
        model.journalNotice == .saveFailed ? tr("Your journal wasn't saved") : tr("Your journal couldn't be read")
    }

    private var noticeMessage: String {
        model.journalNotice == .saveFailed
            ? tr("Germily couldn't write to this phone. Free up some storage, then make your change again.")
            : tr("Germily kept the file and started a new journal. You can export the kept file from Settings, under Data and privacy.")
    }
}

enum AppTab: Hashable {
    case today
    case family
    case lab
    case trophies
    case crew
}

/// The tabs, the sick-mode accessory, Settings, and the log and reward presentations.
struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            TodayScreen()
                .tabItem { Label(tr("Today"), systemImage: "house.fill") }
                .tag(AppTab.today)
            LabScreen()
                .tabItem { Label(tr("Guide"), systemImage: "book.fill") }
                .tag(AppTab.lab)
            FamilyScreen()
                .tabItem { Label(tr("Family"), systemImage: "figure.2.and.child.holdinghands") }
                .tag(AppTab.family)
            if AppConfig.crewEnabled {
                CrewScreen()
                    .tabItem { Label(tr("Crew"), systemImage: "person.3.fill") }
                    .tag(AppTab.crew)
            }
            TrophiesScreen()
                .tabItem { Label(tr("Trophies"), systemImage: "trophy.fill") }
                .tag(AppTab.trophies)
        }
        .tabViewBottomAccessory(isEnabled: model.activeLog != nil && model.selectedTab != .today) {
            SickAccessory()
        }
        .tabBarMinimizeBehavior(.never)
        .sheet(isPresented: $model.showSettings) {
            SettingsScreen()
        }
        .sheet(item: $model.logRequest, onDismiss: { model.showStagedReward() }) { request in
            LogSheet(request: request) { result in
                model.stagedReward = result
            }
        }
        .fullScreenCover(item: $model.pendingReward, onDismiss: { model.offerTrialIfDue() }) { reward in
            RewardView(reward: reward)
        }
        .sheet(isPresented: $model.showTrialOffer) {
            TrialOfferSheet()
        }
        .fullScreenCover(item: $model.pendingVictory, onDismiss: askForReview) { victory in
            VictoryView(victory: victory)
        }
        .fullScreenCover(item: $model.pendingKidVictory, onDismiss: askForReview) { victory in
            KidVictoryView(victory: victory)
        }
        .sheet(item: $model.pendingMilestone) { event in
            SharePreviewSheet(title: tr("Milestone unlocked")) {
                MilestoneShareCard(days: event.days)
            }
            .onAppear {
                Haptics.success()
            }
        }
        .overlay(alignment: .top) {
            ZStack {
                if let toast = model.toast {
                    ToastView(text: toast)
                        .motionTransition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(nanoseconds: 2_200_000_000)
                            model.toast = nil
                        }
                } else if let trick = model.trickFound {
                    TrickToast(trick: trick)
                        .motionTransition(.move(edge: .top).combined(with: .opacity))
                        .task(id: trick) {
                            try? await Task.sleep(nanoseconds: 3_400_000_000)
                            model.trickFound = nil
                        }
                }
            }
            .animation(Tempo.settle, value: model.toast)
            .animation(Tempo.settle, value: model.trickFound)
        }
        .confirmationDialog(tr("Feeling better?"), isPresented: $model.askBetter, titleVisibility: .visible) {
            Button(tr("Yes, I'm better")) {
                Haptics.success()
                model.markBetter()
            }
            Button(tr("Not yet"), role: .cancel) {}
        } message: {
            Text(tr("This ends the current germ and restarts your streak."))
        }
    }

    /// Once a win has closed: the moment to ask for an App Store rating, when one is due.
    private func askForReview() {
        guard ReviewAsk.isDue() else { return }
        ReviewAsk.markAsked()
        requestReview()
    }

}

/// A short confirmation that slides in at the top of the screen.
private struct ToastView: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.background)
            .padding(.horizontal, 18)
            .frame(minHeight: 42)
            .background(palette.ink, in: Capsule())
            .liftShadow()
            .padding(.top, 6)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// A trick of the Today mascot just found: its face, how many are found, and the clue to the next one.
private struct TrickToast: View {
    let trick: MascotTrick
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let found = MascotTrick.allCases.filter { model.data.mascotTricks.contains($0.rawValue) }
        let next = MascotTrick.allCases.first { !found.contains($0) }
        let total = MascotTrick.allCases.count
        HStack(spacing: 12) {
            Image(trick.face)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .padding(4)
                .background(palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Trick found: %@", trick.title))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(next.map { tr("%1$lld of %2$lld · Next clue: %3$@", found.count, total, $0.clue) }
                     ?? tr("%1$lld of %2$lld", found.count, total))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 440)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .liftShadow()
        .padding(.horizontal, Spacing.page)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// The bar above the tab bar while a germ is active and another tab is open.
private struct SickAccessory: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let log = model.activeLog, let germ = model.activeGerm {
            HStack(spacing: 10) {
                GermImage(germ: germ, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(germ.illness.value)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(tr("Day %lld", log.dayCount()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button {
                    model.askBetter = true
                } label: {
                    Text(tr("Better"))
                        .foregroundStyle(palette.background)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(palette.ink)
            }
            .padding(.horizontal, 12)
        }
    }
}
