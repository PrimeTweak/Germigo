import AVFoundation
import CoreTransferable
import UIKit
import UniformTypeIdentifiers

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

/// The whole journal as a JSON backup that Restore can read back.
struct JournalBackup: Transferable {
    let data: AppData

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { (backup: JournalBackup) in
            Persistence.backupData(backup.data) ?? Data()
        }
        .suggestedFileName("petri-backup.json")
    }
}

/// The journal as a CSV file, produced only when the share sheet asks for it.
struct JournalExport: Transferable {
    let logs: [SickLog]
    let catalog: GermCatalog
    let sourceNames: [UUID: String]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { (export: JournalExport) in
            Data(export.csv.utf8)
        }
        .suggestedFileName("petri-journal.csv")
    }

    var csv: String {
        let formatter = ISO8601DateFormatter()
        var rows = ["started,ended,germ,illness,source,sick,severity,points"]
        for log in logs.sorted(by: { $0.startedAt < $1.startedAt }) {
            let germ = catalog.germ(log.germID)
            let ended = log.endedAt.map { formatter.string(from: $0) } ?? ""
            let fields = [
                formatter.string(from: log.startedAt), ended, germ?.name ?? log.germID,
                germ?.illness.value ?? "", sourceNames[log.id] ?? "", log.sufferer.rawValue, String(log.severity),
                String(log.points)
            ]
            rows.append(fields.map(Self.escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
