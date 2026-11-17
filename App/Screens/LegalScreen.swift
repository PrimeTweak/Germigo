import SwiftUI

enum LegalKind: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }
}

struct LegalSection: Codable, Hashable {
    let title: LocalizedText
    let body: LocalizedText
}

/// The privacy policy and terms bundled with the app, so they open offline.
struct LegalContent: Codable {
    let updated: String
    let privacy: [LegalSection]
    let terms: [LegalSection]

    static func load() -> LegalContent? {
        guard let url = Bundle.main.url(forResource: "legal", withExtension: "json"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LegalContent.self, from: raw)
    }
}

struct LegalScreen: View {
    let kind: LegalKind
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var content = LegalContent.load()

    private static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    private var sections: [LegalSection] {
        guard let content else { return [] }
        return kind == .privacy ? content.privacy : content.terms
    }

    private var webURL: URL? {
        kind == .privacy ? AppConfig.privacyURL : AppConfig.termsURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let content {
                    Text(tr("Last updated %@", content.updated))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.element.title.value)
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Text(item.element.body.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if kind == .terms, let eula = Self.standardEULA {
                    Link(tr("Apple's standard license agreement (EULA)"), destination: eula)
                        .font(.subheadline.weight(.semibold))
                }
                if let webURL {
                    Link(tr("Open the web version"), destination: webURL)
                        .font(.subheadline.weight(.semibold))
                }
                if let email = AppConfig.supportEmail, let mail = URL(string: "mailto:" + email) {
                    Link(tr("Contact: %@", email), destination: mail)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .tint(palette.isDark ? palette.lime : Color(hex: 0x3D7BFA))
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(kind == .privacy ? tr("Privacy Policy") : tr("Terms of Use"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(tr("Done")) {
                    dismiss()
                }
            }
        }
    }
}
