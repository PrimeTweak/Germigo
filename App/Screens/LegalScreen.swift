import SwiftUI

enum LegalKind: String, Identifiable {
    case privacy
    case terms
    case health

    var id: String { rawValue }
}

struct LegalSection: Codable, Hashable {
    let title: LocalizedText
    let body: LocalizedText
}

/// The privacy policy, the terms and the health data policy bundled with the app, so they open offline.
struct LegalContent: Codable {
    let updated: String
    let privacy: [LegalSection]
    let terms: [LegalSection]
    let health: [LegalSection]

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
        switch kind {
        case .privacy: return content.privacy
        case .terms: return content.terms
        case .health: return content.health
        }
    }

    private var webURL: URL? {
        switch kind {
        case .privacy: AppConfig.privacyURL
        case .terms: AppConfig.termsURL
        case .health: AppConfig.healthDataURL
        }
    }

    private var title: String {
        switch kind {
        case .privacy: tr("Privacy Policy")
        case .terms: tr("Terms of Use")
        case .health: tr("Health Data Policy")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let content {
                    Text(tr("Last updated %@", content.updated))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                if let publisher = AppConfig.publisherName {
                    Text(tr("Germily is published by %@.", publisher))
                        .font(.subheadline)
                        .foregroundStyle(palette.ink)
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
                    Link(destination: eula) {
                        Text(tr("Apple's standard license agreement (EULA)")).underline()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                if let webURL {
                    Link(destination: webURL) {
                        Text(tr("Open the web version")).underline()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                if let email = AppConfig.supportEmail, let mail = URL(string: "mailto:" + email) {
                    Link(destination: mail) {
                        Text(tr("Contact: %@", email)).underline()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .tint(palette.isDark ? palette.accent : palette.ink)
            .padding(.horizontal, Spacing.page)
            .padding(.vertical, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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
    }
}
