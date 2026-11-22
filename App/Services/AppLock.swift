import LocalAuthentication
import SwiftUI
import UIKit

/// The optional app lock: Germily stays covered until Face ID, Touch ID or the passcode opens it.
/// Nothing about the face or the finger leaves iOS; the app only learns yes or no.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()

    private(set) var isLocked: Bool
    /// The cover above every screen and sheet while the app is in the background.
    @ObservationIgnored private var cover: UIWindow?
    /// Face ID is offered once by itself after a lock; after that, the button asks again.
    @ObservationIgnored private var offered = false
    @ObservationIgnored private var asking = false

    private init() {
        isLocked = AppModel.shared.data.settings.appLockOn
    }

    /// The unlock method the phone has, for labels and symbols.
    static var method: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    static var symbol: String {
        method == .touchID ? "touchid" : "faceid"
    }

    static var methodName: String {
        switch method {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return tr("your passcode")
        }
    }

    /// Checks the person once before the lock is turned on; false when the phone has no passcode or they cancel.
    static func confirm() async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: tr("Turn on the app lock."))) ?? false
    }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Locks when the app leaves for the background, and offers Face ID once when it comes back.
    func sceneChanged(_ phase: ScenePhase, enabled: Bool, palette: Palette) {
        guard enabled else { return }
        switch phase {
        case .background:
            isLocked = true
            offered = false
            showCover(palette: palette)
        case .active where isLocked && !offered:
            offered = true
            Task { await unlock() }
        default:
            break
        }
    }

    func unlock() async {
        guard isLocked, !asking else { return }
        asking = true
        defer { asking = false }
        let context = LAContext()
        let opened = (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: tr("Unlock your journal."))) ?? false
        guard opened else { return }
        isLocked = false
        hideCover()
    }

    private func showCover(palette: Palette) {
        guard cover == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: LockScreen().environment(\.palette, palette))
        window.isHidden = false
        cover = window
    }

    private func hideCover() {
        cover?.isHidden = true
        cover = nil
    }
}

/// What shows while Germily is locked: the wordmark and the way back in.
struct LockScreen: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Wordmark(size: 56)
            Text(tr("Germily is locked."))
                .font(.body)
                .foregroundStyle(palette.inkSecondary)
            Spacer()
            Button {
                Task {
                    await AppLock.shared.unlock()
                }
            } label: {
                Label(tr("Unlock"), systemImage: AppLock.symbol)
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}
