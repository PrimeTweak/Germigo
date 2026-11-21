import SwiftUI

/// Every photo of the household, newest month first, grouped by illness, with a filter per person.
struct AlbumScreen: View {
    private struct Batch: Identifiable {
        let id: String
        let person: Person
        let germ: Germ?
        let dates: String?
        let photos: [PatientPhoto]
    }

    private struct Month: Identifiable {
        let id: Date
        let batches: [Batch]
        var count: Int { batches.reduce(0) { $0 + $1.photos.count } }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var person: Person?
    @State private var seed: PhotoSeed?
    @State private var focus: PhotoFocus?
    @State private var showPaywall = false
    @State private var width: CGFloat = 0

    private var visible: [PatientPhoto] {
        model.data.photos
            .filter { (person == nil || $0.person == person) && model.isShown($0.takenAt) }
            .sorted { $0.takenAt > $1.takenAt }
    }

    private var hidden: Int {
        model.data.photos.filter { (person == nil || $0.person == person) && !model.isShown($0.takenAt) }.count
    }

    var body: some View {
        let photos = visible
        let months = group(photos)
        let order = months.flatMap { $0.batches.flatMap { $0.photos.map { $0.id } } }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(photos.isEmpty ? tr("No photos yet")
                                    : trCount(photos.count, one: "%lld photo, newest first", other: "%lld photos, newest first"))
                    .font(.subheadline)
                    .foregroundStyle(palette.ink.opacity(0.8))
                    .padding(.horizontal, 4)
                if model.people.count > 1 {
                    chips
                }
                if photos.isEmpty {
                    empty
                }
                ForEach(months) { month in
                    SectionHeader(title: month.id.formatted(.dateTime.month(.wide).year()),
                                  trailing: trCount(month.count, one: "%lld photo", other: "%lld photos"))
                    ForEach(month.batches) { batch in
                        card(batch, order: order)
                    }
                }
                if hidden > 0 {
                    LockedHistoryRow(count: hidden)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .animation(.snappy, value: person)
        }
        .background(CharacterWash(tint: TabWash.family))
        .navigationTitle(tr("Album"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    add()
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel(tr("Add a photo"))
            }
        }
        .sheet(item: $seed) { seed in
            AddPhotoSheet(seed: seed)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(item: $focus) { focus in
            PhotoViewer(focus: focus)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil)
                ForEach(model.people, id: \.self) { member in
                    chip(member)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func chip(_ member: Person?) -> some View {
        let selected = member == person
        return Button {
            withAnimation(.snappy) {
                person = member
            }
        } label: {
            HStack(spacing: 6) {
                if let member {
                    BuddyView(look: model.look(of: member), sick: true, size: 28)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .background((selected ? palette.background : palette.ink).opacity(0.16), in: Circle())
                }
                Text(member.map { model.name(for: $0) } ?? tr("Everyone"))
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(selected ? palette.background : palette.ink)
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 44)
            .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(palette.inkTertiary)
            Text(tr("Add a photo on a sick day, from someone's file, or with the button at the top."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .germigoCard()
    }

    private func card(_ batch: Batch, order: [UUID]) -> some View {
        let side = max(60, (width - 24 - 12) / 3)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BuddyView(look: model.look(of: batch.person), sick: true, size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.name(for: batch.person))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(subtitle(batch))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 8)
                if let germ = batch.germ {
                    GermImage(germ: germ, size: 36)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(batch.photos) { photo in
                    Button {
                        focus = PhotoFocus(ids: order, start: photo.id)
                    } label: {
                        PhotoThumb(id: photo.id, side: side, radius: 14)
                            .overlay(alignment: .bottomLeading) {
                                if let day = model.sickDay(of: photo) {
                                    Text(tr("Day %lld", day))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(.black.opacity(0.42), in: Capsule())
                                        .padding(6)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .germigoCard(padding: 0)
    }

    private func subtitle(_ batch: Batch) -> String {
        guard let germ = batch.germ else { return tr("Other photos") }
        return [germ.illness.value, batch.dates].compactMap { $0 }.joined(separator: " · ")
    }

    /// Months newest first; inside a month, illnesses by their newest photo, each one's photos oldest first.
    private func group(_ photos: [PatientPhoto]) -> [Month] {
        let calendar = Calendar.current
        var months: [Date: [PatientPhoto]] = [:]
        for photo in photos {
            let start = calendar.dateInterval(of: .month, for: photo.takenAt)?.start ?? photo.takenAt
            months[start, default: []].append(photo)
        }
        return months.keys.sorted(by: >).map { start in
            var keys: [String] = []
            var batches: [String: [PatientPhoto]] = [:]
            for photo in months[start] ?? [] {
                let key = photo.logID?.uuidString ?? photo.illnessID?.uuidString ?? "other-" + String(describing: photo.person)
                if batches[key] == nil { keys.append(key) }
                batches[key, default: []].append(photo)
            }
            let list = keys.compactMap { key -> Batch? in
                guard let items = batches[key], let first = items.first else { return nil }
                return Batch(id: key, person: first.person, germ: model.germ(of: first), dates: dates(of: first),
                             photos: items.sorted { $0.takenAt < $1.takenAt })
            }
            return Month(id: start, batches: list)
        }
    }

    private func dates(of photo: PatientPhoto) -> String? {
        let day: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day()) }
        if let id = photo.logID, let log = model.data.logs.first(where: { $0.id == id }) {
            return log.endedAt.map { tr("%1$@ to %2$@", day(log.startedAt), day($0)) } ?? tr("Since %@", day(log.startedAt))
        }
        if let id = photo.illnessID, let illness = model.data.kidIllnesses.first(where: { $0.id == id }) {
            return illness.endedAt.map { tr("%1$@ to %2$@", day(illness.startedAt), day($0)) }
                ?? tr("Since %@", day(illness.startedAt))
        }
        return nil
    }

    /// New photo for the person filtered on, else for whoever is sick today, else for the parent.
    private func add() {
        guard model.hasPass else {
            showPaywall = true
            return
        }
        let now = Date()
        let who = person ?? model.people.first { model.photoLink(for: $0, on: now) != .unlinked } ?? .me
        seed = PhotoSeed(person: who, takenAt: now, link: model.photoLink(for: who, on: now))
    }
}
