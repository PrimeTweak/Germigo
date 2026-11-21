import AVFoundation
import CoreTransferable
import UIKit
import UniformTypeIdentifiers

enum SoundEffect: String {
    case flap
    case reveal
    case badge
}

/// From 10 PM to 7 AM: reminders wait for morning and sounds stay off, so nobody wakes up.
enum QuietHours {
    static let startMinute = 22 * 60
    static let endMinute = 7 * 60

    static func contains(_ date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minute >= startMinute || minute < endMinute
    }
}

/// Plays short bundled sounds; follows the silent switch and the quiet hours.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [SoundEffect: AVAudioPlayer] = [:]

    func play(_ effect: SoundEffect) {
        guard AppModel.shared.data.settings.soundsOn, !QuietHours.contains(Date()) else { return }
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

/// The whole journal and its photos as a JSON backup that Restore can read back.
struct JournalBackup: Transferable {
    let data: AppData

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { (backup: JournalBackup) in
            let photos = PhotoStore.files(for: backup.data.photos.map { $0.id })
            return Persistence.backupData(backup.data, photos: photos) ?? Data()
        }
        .suggestedFileName("petri-backup.json")
    }
}

/// The doctor summary as a letter-size PDF: the summary lines, then each illness's photos, three to a row.
struct DoctorPacket: Transferable {
    struct Section {
        let title: String
        let photoIDs: [UUID]
    }

    let lines: [String]
    let sections: [Section]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { (packet: DoctorPacket) in
            packet.pdf()
        }
        .suggestedFileName("petri-for-the-doctor.pdf")
    }

    func pdf() -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let width = page.width - margin * 2
        let gap: CGFloat = 12
        let cell = (width - gap * 2) / 3
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            var y = margin
            context.beginPage()
            func makeRoom(_ height: CGFloat) {
                guard y + height > page.height - margin else { return }
                context.beginPage()
                y = margin
            }
            func write(_ text: String, font: UIFont, after: CGFloat) {
                let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.black])
                let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
                let height = ceil(string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                      options: options, context: nil).height)
                makeRoom(height)
                string.draw(with: CGRect(x: margin, y: y, width: width, height: height), options: options, context: nil)
                y += height + after
            }
            for (index, line) in lines.enumerated() {
                write(line, font: index == 0 ? .boldSystemFont(ofSize: 20) : .systemFont(ofSize: 12), after: index == 0 ? 12 : 6)
            }
            for section in sections where !section.photoIDs.isEmpty {
                y += gap
                write(section.title, font: .boldSystemFont(ofSize: 14), after: 8)
                for (index, id) in section.photoIDs.enumerated() {
                    let column = index % 3
                    if column == 0 { makeRoom(cell) }
                    let frame = CGRect(x: margin + CGFloat(column) * (cell + gap), y: y, width: cell, height: cell)
                    if let image = PhotoStore.thumbnail(id, side: 200) {
                        image.draw(in: Self.fitted(image.size, in: frame))
                    }
                    if column == 2 || index == section.photoIDs.count - 1 { y += cell + gap }
                }
            }
        }
    }

    private static func fitted(_ size: CGSize, in frame: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return frame }
        let scale = min(frame.width / size.width, frame.height / size.height)
        let fit = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: frame.midX - fit.width / 2, y: frame.midY - fit.height / 2, width: fit.width, height: fit.height)
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
