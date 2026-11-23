import SwiftUI

extension Theme {
    var title: String {
        switch self {
        case .agar: return tr("Standard")
        case .coral: return tr("Coral")
        case .sky: return tr("Sky")
        case .mint: return tr("Mint")
        case .bubblegum: return tr("Bubblegum")
        }
    }
}

/// How one piece of a collection stands: the one in use, open to pick, or still to earn.
private enum PieceState {
    case inUse
    case open
    case locked
}

/// The head of a collection page: how many pieces are open, and a line about how the rest open.
private struct CollectionHead: View {
    let open: Int
    let total: Int
    let note: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(tr("%1$lld of %2$lld", open, total))
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
                .fixedSize()
            Text(note)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// The line under a piece: a check when in use, a padlock that wiggles when a locked piece is tapped.
private struct PieceLine: View {
    let text: String
    let state: PieceState
    let nudges: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if state == .inUse {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
            } else if state == .locked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .symbolEffect(.wiggle, value: nudges)
            }
            Text(text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(state == .inUse ? .semibold : .regular))
        .foregroundStyle(state == .inUse ? palette.accent : palette.inkSecondary)
    }
}

/// The app icons as a small collection: the one in use, the open ones, and what opens the others.
struct AppIconScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current = AppIconOption.germily
    @State private var popped: AppIconOption?
    @State private var nudges: [AppIconOption: Int] = [:]
    @State private var showPaywall = false

    var body: some View {
        let options = AppIconOption.allCases
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CollectionHead(open: options.filter { model.isIconUnlocked($0) }.count, total: options.count,
                               note: tr("New icons unlock as the season goes."))
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(options) { option in
                        cell(option)
                    }
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("App icon"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .looks)
        }
        .onAppear {
            current = AppIconManager.current
        }
    }

    private func standing(of option: AppIconOption) -> PieceState {
        if current == option { return .inUse }
        return model.isIconUnlocked(option) ? .open : .locked
    }

    private func caption(for option: AppIconOption, state: PieceState) -> String {
        switch state {
        case .inUse: return tr("In use")
        case .open: return option == .germily || option == .daylight ? option.requirement : tr("Unlocked")
        case .locked: return option.requirement
        }
    }

    private func cell(_ option: AppIconOption) -> some View {
        let state = standing(of: option)
        let line = caption(for: option, state: state)
        return Button {
            pick(option, unlocked: state != .locked)
        } label: {
            VStack(spacing: 0) {
                Image(option.previewAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 5)
                    .padding(6)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .strokeBorder(state == .inUse ? palette.accent : Color.clear, lineWidth: 3)
                    }
                    .scaleEffect(popped == option ? 1.12 : 1)
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.top, 6)
                PieceLine(text: line, state: state, nudges: nudges[option, default: 0])
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityValue(line)
        .accessibilityAddTraits(state == .inUse ? .isSelected : [])
    }

    private func pick(_ option: AppIconOption, unlocked: Bool) {
        Haptics.tap()
        guard unlocked else {
            nudges[option, default: 0] += 1
            if option == .soupBowl { showPaywall = true }
            return
        }
        guard option != current else { return }
        Task {
            guard await AppIconManager.apply(option) else { return }
            current = option
            Haptics.success()
            guard !reduceMotion else { return }
            withAnimation(Tempo.pop) {
                popped = option
            }
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(Tempo.pop) {
                popped = nil
            }
        }
    }
}

/// The themes as a small collection: each one takes the color of a badge, and the Season Pass opens them all.
struct ThemeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var nudges: [Theme: Int] = [:]

    var body: some View {
        let themes = Theme.allCases
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 2)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CollectionHead(open: themes.filter { model.isThemeUnlocked($0) }.count, total: themes.count,
                               note: tr("Each badge opens its color."))
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(themes, id: \.self) { theme in
                        cell(theme)
                    }
                }
                if !model.hasPass {
                    PassOfferLink(reason: .looks)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Theme"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func standing(of theme: Theme) -> PieceState {
        if model.data.settings.theme == theme { return .inUse }
        return model.isThemeUnlocked(theme) ? .open : .locked
    }

    private func caption(for theme: Theme, state: PieceState) -> String {
        guard let badge = theme.badgeID.flatMap(BadgeCatalog.badge) else {
            return state == .inUse ? tr("In use") : tr("Always yours")
        }
        return state == .inUse ? tr("In use") : tr("%@ badge", badge.title)
    }

    private func cell(_ theme: Theme) -> some View {
        let state = standing(of: theme)
        let line = caption(for: theme, state: state)
        return Button {
            pick(theme, unlocked: state != .locked)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ThemePreview(look: Palette.make(theme: theme, scheme: palette.isDark ? .dark : .light), inUse: state == .inUse)
                Text(theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.top, 10)
                    .padding(.horizontal, 2)
                PieceLine(text: line, state: state, nudges: nudges[theme, default: 0])
                    .padding(.top, 2)
                    .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.title)
        .accessibilityValue(line)
        .accessibilityAddTraits(state == .inUse ? .isSelected : [])
    }

    private func pick(_ theme: Theme, unlocked: Bool) {
        Haptics.tap()
        guard unlocked else {
            nudges[theme, default: 0] += 1
            return
        }
        withAnimation(Tempo.quick) {
            model.updateSettings { $0.theme = theme }
        }
    }
}

/// A theme at a glance: its ground, a counter, a card, a button and a switch in its accent.
private struct ThemePreview: View {
    let look: Palette
    let inUse: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(verbatim: "12")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(look.ink)
            Capsule()
                .fill(look.surface)
                .frame(height: 10)
            HStack(spacing: 0) {
                Text(tr("I'm sick"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(look.onAccent)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 24)
                    .background(look.accent, in: Capsule())
                Spacer(minLength: 6)
                Capsule()
                    .fill(look.accent)
                    .frame(width: 40, height: 24)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(Color.white)
                            .padding(2)
                    }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.background, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(inUse ? look.accent : palette.hairline, lineWidth: inUse ? 3 : 1)
        }
        .accessibilityHidden(true)
    }
}

/// Every character, to keep in or leave out of the choices when someone is added.
struct CharactersScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var nudges: [Int: Int] = [:]
    @State private var blocked = false

    private var hidden: Set<Int> { model.data.settings.hiddenLooks }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 4)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CollectionHead(open: Looks.order.filter { !hidden.contains($0) }.count, total: Looks.count,
                               note: tr("Shown when you add someone. Tap one to hide it or bring it back."))
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Looks.order, id: \.self) { look in
                        cell(look)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if blocked {
                        Text(tr("At least one character you can pick stays shown."))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .transition(.opacity)
                    }
                    Text(tr("A character someone already has stays theirs, even hidden."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                Button(tr("Show all")) {
                    Haptics.tap()
                    withAnimation(Tempo.quick) {
                        blocked = false
                        model.updateSettings { $0.hiddenLooks = [] }
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 50))
                .disabled(hidden.isEmpty)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Characters"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cell(_ look: Int) -> some View {
        let shown = !hidden.contains(look)
        let open = model.isLookOpen(look)
        let name = tr("Character %lld", look + 1)
        return Button {
            toggle(look)
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(Buddy.tint(look).opacity(palette.isDark ? 0.24 : 0.34))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        BuddyView(look: look, size: 50)
                    }
                    .saturation(shown ? 1 : 0)
                    .opacity(shown ? 1 : 0.45)
                    .overlay(alignment: .bottomTrailing) {
                        if !open {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 20, height: 20)
                                .background(shown ? palette.accent : palette.inkTertiary, in: Circle())
                                .overlay {
                                    Circle().stroke(palette.background, lineWidth: 2)
                                }
                        }
                    }
                HStack(spacing: 3) {
                    Image(systemName: shown ? "checkmark" : "eye.slash")
                        .font(.caption2.weight(.bold))
                        .symbolEffect(.wiggle, value: nudges[look, default: 0])
                    Text(shown ? tr("Shown") : tr("Hidden"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(shown ? palette.accent : palette.inkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(open ? name : name + ", " + tr("Needs the Season Pass"))
        .accessibilityValue(shown ? tr("Shown") : tr("Hidden"))
        .accessibilityHint(shown ? tr("Hides it from the choices.") : tr("Brings it back to the choices."))
    }

    /// Hides or brings back a look; the last look that can be picked stays and wiggles instead.
    private func toggle(_ look: Int) {
        Haptics.tap()
        if hidden.contains(look) {
            withAnimation(Tempo.quick) {
                blocked = false
                model.updateSettings { $0.hiddenLooks.remove(look) }
            }
        } else if Looks.canHide(look, hidden: hidden, hasPass: model.hasPass) {
            withAnimation(Tempo.quick) {
                model.updateSettings { $0.hiddenLooks.insert(look) }
            }
        } else {
            nudges[look, default: 0] += 1
            withAnimation(Tempo.quick) {
                blocked = true
            }
        }
    }
}
