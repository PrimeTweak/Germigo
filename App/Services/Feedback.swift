import AVFoundation
import UIKit

enum SoundEffect: String {
    case flap
    case reveal
    case badge
}

/// Plays short bundled sounds; follows the silent switch.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [SoundEffect: AVAudioPlayer] = [:]

    func play(_ effect: SoundEffect) {
        guard AppModel.shared.data.settings.soundsOn else { return }
        if players[effect] == nil, let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            players[effect] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}

/// Haptic taps, tied to the same setting as sounds.
@MainActor
enum Haptics {
    private static var enabled: Bool {
        AppModel.shared.data.settings.soundsOn
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func thud() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Switches the home screen icon.
@MainActor
enum AppIconManager {
    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return AppIconOption.allCases.first { $0.alternateName == name } ?? .petri
    }

    static func apply(_ option: AppIconOption) async -> Bool {
        guard UIApplication.shared.supportsAlternateIcons else { return false }
        do {
            try await UIApplication.shared.setAlternateIconName(option.alternateName)
            return true
        } catch {
            return false
        }
    }
}

/// Writes the journal as a CSV file the parent can keep.
enum CSVExporter {
    static func export(logs: [SickLog], catalog: GermCatalog, sourceName: (GermSource) -> String) -> URL? {
        let formatter = ISO8601DateFormatter()
        var rows = ["started,ended,germ,illness,source,severity,points"]
        for log in logs.sorted(by: { $0.startedAt < $1.startedAt }) {
            let germ = catalog.germ(log.germID)
            let ended = log.endedAt.map { formatter.string(from: $0) } ?? ""
            let fields = [
                formatter.string(from: log.startedAt), ended, germ?.name ?? log.germID,
                germ?.illness.value ?? "", sourceName(log.source), String(log.severity), String(log.points)
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("petri-journal.csv")
        do {
            try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
