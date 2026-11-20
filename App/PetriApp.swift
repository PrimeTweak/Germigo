import SwiftUI

@main
struct PetriApp: App {
    @State private var model = AppModel.shared
    @State private var purchases = PurchaseManager.shared
    @State private var crew = CrewStore.shared
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
            } else if phase == .background, crew.isMember {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(AppConfig.refreshTaskID)) {
            await CrewStore.shared.backgroundRefresh()
            BackgroundRefresh.schedule()
        }
    }
}

/// Applies the chosen appearance, then resolves the palette for it.
struct RootView: View {
    @Environment(AppModel.self) private var model

    private var scheme: ColorScheme? {
        if model.data.settings.theme == .nightShift { return .dark }
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

    var body: some View {
        let palette = Palette.make(theme: model.data.settings.theme, scheme: colorScheme, contrast: contrast)
        Group {
            if model.data.onboardingDone {
                MainTabs()
            } else {
                OnboardingFlow()
            }
        }
        .environment(\.palette, palette)
        .tint(palette.ink)
        .animation(.easeInOut(duration: 0.35), value: model.data.onboardingDone)
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
            ? tr("Petri couldn't write to this phone. Free up some storage, then make your change again.")
            : tr("Petri kept the file and started a new journal. You can export the kept file from Settings, under Your Data.")
    }
}

enum AppTab: Hashable {
    case today
    case album
    case lab
    case crew
    case season
}

/// The tabs, the sick-mode accessory, and the log and reward presentations.
struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @State private var stagedReward: RewardResult?

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            TodayScreen()
                .tabItem { Label(tr("Today"), systemImage: "house.fill") }
                .tag(AppTab.today)
            AlbumScreen()
                .tabItem { Label(tr("Album"), systemImage: "square.stack.fill") }
                .tag(AppTab.album)
            LabScreen()
                .tabItem { Label(tr("Lab"), systemImage: "flask.fill") }
                .tag(AppTab.lab)
            if AppConfig.crewEnabled {
                CrewScreen()
                    .tabItem { Label(tr("Crew"), systemImage: "person.2.fill") }
                    .tag(AppTab.crew)
            }
            SeasonScreen()
                .tabItem { Label(tr("Season"), systemImage: "chart.bar.fill") }
                .tag(AppTab.season)
        }
        .tabViewBottomAccessory(isEnabled: model.activeLog != nil) {
            SickAccessory()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $model.logRequest, onDismiss: presentStagedReward) { request in
            LogSheet(request: request) { result in
                stagedReward = result
            }
        }
        .fullScreenCover(item: $model.pendingReward) { reward in
            RewardView(reward: reward)
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(nanoseconds: 2_200_000_000)
                            model.toast = nil
                        }
                }
            }
            .animation(.snappy, value: model.toast)
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

    /// Lets the counter flip on Today before the reward covers the screen.
    private func presentStagedReward() {
        guard let reward = stagedReward else { return }
        stagedReward = nil
        SoundPlayer.shared.play(.flap)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            model.pendingReward = reward
        }
    }
}

/// A short confirmation that slides in at the top of the screen.
private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(hex: Swatch.night))
            .padding(.horizontal, 18)
            .frame(minHeight: 42)
            .background(Color(hex: Swatch.lime), in: Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
            .padding(.top, 6)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// The bar above the tab bar while a germ is active.
private struct SickAccessory: View {
    @Environment(AppModel.self) private var model

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
                        .foregroundStyle(Color(hex: Swatch.night))
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(hex: Swatch.coralDeep))
            }
            .padding(.horizontal, 12)
        }
    }
}
