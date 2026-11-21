import SwiftUI

/// Adds a kid's illness and starts the parent's exposure countdown.
struct KidIllnessSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var kidID: UUID?
    @State private var germID: String?
    @State private var startedAt = Date()
    @State private var watch = true
    @State private var newKidName = ""
    @State private var saved = false
    @State private var added: KidIllness?

    /// False for the germs that have no known incubation window, so nothing to watch.
    private var hasWindow: Bool {
        guard let germID, let germ = model.catalog.germ(germID) else { return true }
        return germ.incubationMinHours != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.data.kids.isEmpty {
                        TextField(tr("Kid's name"), text: $newKidName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 16) {
                                ForEach(model.data.kids) { kid in
                                    Button {
                                        kidID = kid.id
                                    } label: {
                                        VStack(spacing: 6) {
                                            AvatarView(name: kid.name, gradient: AvatarColors.gradient(kid.colorIndex), size: 54)
                                                .padding(4)
                                                .overlay {
                                                    Circle().strokeBorder(kidID == kid.id ? palette.ink : Color.clear, lineWidth: 2.5)
                                                }
                                            Text(kid.name)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(palette.ink)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                    Text(tr("What do they have?"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    GermPicker(selection: $germID)
                    VStack(spacing: 0) {
                        DatePicker(tr("Since"), selection: $startedAt, in: AppModel.earliestNewEntry...Date(),
                                   displayedComponents: [.date, .hourAndMinute])
                            .frame(minHeight: 54)
                        if hasWindow {
                            Divider()
                            Toggle(tr("Watch my window"), isOn: $watch)
                                .frame(minHeight: 54)
                        }
                    }
                    .tint(.green)
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 16)
                    .petriCard(padding: 0)
                    Text(hasWindow
                         ? tr("Watching sends a check-in when your window opens and closes. During the last 8 hours of the window, opening Petri also puts the countdown on the Lock Screen.")
                         : tr("No countdown for this one. The case file explains what to watch for."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("A kid is sick"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $added) { illness in
                ProtectHomeView(illness: illness) {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Add")) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if kidID == nil { kidID = model.data.kids.first?.id }
            }
        }
    }

    private var canSave: Bool {
        guard germID != nil else { return false }
        if model.data.kids.isEmpty {
            return !newKidName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return kidID != nil
    }

    private func save() {
        guard !saved, let germID else { return }
        var target = kidID
        if model.data.kids.isEmpty {
            let kid = Kid(name: newKidName.trimmingCharacters(in: .whitespaces), colorIndex: 0)
            model.saveKid(kid)
            target = kid.id
        }
        guard let target else { return }
        saved = true
        let illness = model.addKidIllness(kidID: target, germID: germID, startedAt: startedAt)
        if watch && hasWindow {
            Task {
                _ = await NotificationManager.requestAuthorization()
                model.setWatching(illness.id, watching: true)
            }
        }
        if model.household != nil {
            added = illness
        } else {
            dismiss()
        }
    }
}
