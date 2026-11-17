import SwiftUI

@main
struct PetriApp: App {
    @State private var model = AppModel.shared
    @State private var purchases = PurchaseManager.shared
    @State private var crew = CrewStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
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

    var body: some View {
        let palette = Palette.make(theme: model.data.settings.theme, scheme: colorScheme)
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
    }
}

enum AppTab: Hashable {
    case today
    case album
    case crew
    case season
}

/// The four tabs, the sick-mode accessory, and the log and reward presentations.
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
                Button(tr("Better")) {
                    Haptics.success()
                    model.markBetter()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(hex: 0xFF4F42))
            }
            .padding(.horizontal, 12)
        }
    }
}
