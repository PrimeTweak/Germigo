import PhotosUI
import SwiftUI

/// Where a new photo is filed: one of the person's illnesses that day, or nothing in particular.
enum PhotoLink: Hashable {
    case unlinked
    case log(UUID)
    case illness(UUID)

    init(_ entry: DayEntry) {
        if let id = entry.logID {
            self = .log(id)
        } else if let id = entry.illnessID {
            self = .illness(id)
        } else {
            self = .unlinked
        }
    }
}

/// Who, when and what a new photo is about, as the page that asked for it knows them.
struct PhotoSeed: Identifiable {
    let id = UUID()
    let person: Person
    let takenAt: Date
    let link: PhotoLink
}

extension AppModel {
    /// The illness a photo was filed under, if any.
    func germ(of photo: PatientPhoto) -> Germ? {
        let id = photo.logID.flatMap { id in data.logs.first { $0.id == id }?.germID }
            ?? photo.illnessID.flatMap { id in data.kidIllnesses.first { $0.id == id }?.germID }
        return id.flatMap { catalog.germ($0) }
    }

    /// The day of its illness a photo was taken on, 1 for the first day.
    func sickDay(of photo: PatientPhoto) -> Int? {
        let start = photo.logID.flatMap { id in data.logs.first { $0.id == id }?.startedAt }
            ?? photo.illnessID.flatMap { id in data.kidIllnesses.first { $0.id == id }?.startedAt }
        guard let start, photo.takenAt >= Calendar.current.startOfDay(for: start) else { return nil }
        return StreakMath.days(from: start, to: photo.takenAt) + 1
    }

    /// Where a new photo of someone on a given day goes: the illness they had that day, if any.
    func photoLink(for person: Person, on day: Date) -> PhotoLink {
        DayEngine.entries(on: day, data: data, catalog: catalog, now: Date())
            .first { $0.person == person }
            .map { PhotoLink($0) } ?? .unlinked
    }
}

/// A set of photos opened full screen, starting at one of them.
struct PhotoFocus: Identifiable {
    let id = UUID()
    let ids: [UUID]
    let start: UUID
}

/// A photo from the household's files, square and rounded.
struct PhotoThumb: View {
    let id: UUID
    var side: CGFloat = 74
    var radius: CGFloat = 18
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if let image = PhotoStore.thumbnail(id, side: side) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                palette.ink.opacity(0.08)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(palette.inkTertiary)
                    }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityLabel(tr("Photo"))
    }
}

/// A row of thumbnails that open full screen, with an optional tile to add one more.
struct PhotoRow: View {
    let photos: [PatientPhoto]
    var side: CGFloat = 74
    var onAdd: (() -> Void)?
    @Environment(\.palette) private var palette
    @State private var focus: PhotoFocus?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        focus = PhotoFocus(ids: photos.map { $0.id }, start: photo.id)
                    } label: {
                        PhotoThumb(id: photo.id, side: side, radius: side * 0.24)
                    }
                    .buttonStyle(PressableStyle())
                    .motionTransition(.scale(scale: 0.3).combined(with: .opacity))
                }
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(palette.inkSecondary)
                            .frame(width: side, height: side)
                            .overlay {
                                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                                    .strokeBorder(palette.ink.opacity(0.16), lineWidth: 2)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(tr("Add a photo"))
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .fullScreenCover(item: $focus) { focus in
            PhotoViewer(focus: focus)
        }
    }
}

/// New photos: taken now or picked from the library, then filed under someone, a moment and an illness.
struct AddPhotoSheet: View {
    private struct LinkOption: Hashable {
        let link: PhotoLink
        let title: String
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var images: [UIImage] = []
    @State private var picked: [PhotosPickerItem] = []
    @State private var person: Person
    @State private var takenAt: Date
    @State private var link: PhotoLink
    @State private var showCamera = false
    @State private var saving = false
    @State private var editingWhen = false

    init(seed: PhotoSeed) {
        _person = State(initialValue: seed.person)
        _takenAt = State(initialValue: seed.takenAt)
        _link = State(initialValue: seed.link)
    }

    private var members: [Person] {
        model.data.kids.map { Person.kid($0.id) } + [.me] + (model.data.partnerName == nil ? [] : [.partner])
    }

    private var options: [LinkOption] {
        DayEngine.entries(on: takenAt, data: model.data, catalog: model.catalog, now: Date())
            .filter { $0.person == person }
            .map { LinkOption(link: PhotoLink($0), title: title(of: $0)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    preview
                        .padding(.bottom, 6)
                    label(tr("Who"))
                    people
                    let choices = options
                    if !choices.isEmpty {
                        label(tr("For"))
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(choices, id: \.self) { option in
                                    ChoiceChip(title: option.title, selected: link == option.link) {
                                        link = option.link
                                    }
                                }
                                ChoiceChip(title: tr("Not linked"), selected: link == .unlinked) {
                                    link = .unlinked
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    label(tr("When"))
                    when
                    Label(tr("Photos stay on this phone and in your backups. Germigo never uploads them."), systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    Button {
                        save()
                    } label: {
                        Label(person == .me ? tr("Add to your album") : tr("Add to %@'s album", model.name(for: person)),
                              systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                    .disabled(images.isEmpty || saving)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(images.count > 1 ? tr("New photos") : tr("New photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                    .tint(palette.ink)
                }
            }
            .onChange(of: picked) { _, items in
                load(items)
            }
            .onChange(of: person) { _, _ in
                fixLink()
            }
            .onChange(of: takenAt) { _, _ in
                fixLink()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    withAnimation(Tempo.settle) {
                        images = [image]
                    }
                } onClose: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(palette.surface)
            if images.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.bottom, 6)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label(tr("Take a photo"), systemImage: "camera.fill")
                        }
                        .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                    }
                    PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) {
                        Label(tr("Choose photos"), systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                }
                .padding(.horizontal, 36)
            } else {
                TabView {
                    ForEach(images.indices, id: \.self) { index in
                        Color.clear
                            .overlay {
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(Tempo.quick) {
                            images = []
                            picked = []
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.45), in: Circle())
                            .hitTarget(width: 40, height: 40)
                    }
                    .padding(12)
                    .accessibilityLabel(tr("Start over"))
                }
                .motionTransition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(height: 300)
    }

    private var people: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(members, id: \.self) { member in
                    PersonChip(look: model.look(of: member), sick: model.isSick(member), name: model.name(for: member),
                               selected: member == person) {
                        withAnimation(Tempo.quick) {
                            person = member
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.inkSecondary)
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }

    /// When the photo was taken, in words; a tap opens the calendar and the clock.
    private var when: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(Tempo.quick) {
                    editingWhen.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundStyle(palette.inkSecondary)
                    Text(whenTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkSecondary)
                        .rotationEffect(.degrees(editingWhen ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint(editingWhen ? tr("Hides the calendar") : tr("Shows the calendar"))
            if editingWhen {
                DatePicker(tr("When"), selection: $takenAt, in: ...Date())
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(palette.accent)
                    .padding(8)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .motionTransition(.opacity)
            }
        }
    }

    private var whenTitle: String {
        let calendar = Calendar.current
        let time = takenAt.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(takenAt) {
            return calendar.component(.hour, from: takenAt) >= 18 ? tr("Tonight, %@", time) : tr("Today, %@", time)
        }
        if calendar.isDateInYesterday(takenAt) {
            return tr("Yesterday, %@", time)
        }
        return takenAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func title(of entry: DayEntry) -> String {
        let illness = model.catalog.germ(entry.germID)?.illness.value ?? entry.germID
        return tr("%1$@, day %2$lld", illness, entry.dayNumber)
    }

    /// Keeps the illness only if the chosen person still had it on the chosen day.
    private func fixLink() {
        guard link != .unlinked, !options.contains(where: { $0.link == link }) else { return }
        link = options.first?.link ?? .unlinked
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = PhotoStore.image(from: data) {
                    loaded.append(image)
                }
            }
            withAnimation(Tempo.settle) {
                images = loaded
            }
        }
    }

    private func save() {
        saving = true
        let pictures = images
        let who = person
        let when = takenAt
        let target = link
        Task {
            let ids = await Task.detached(priority: .userInitiated) {
                pictures.compactMap { PhotoStore.save($0) }
            }.value
            if ids.isEmpty {
                model.toast = tr("The photo couldn't be saved.")
            } else {
                var logID: UUID?
                var illnessID: UUID?
                switch target {
                case .log(let id): logID = id
                case .illness(let id): illnessID = id
                case .unlinked: break
                }
                withAnimation(Tempo.pop) {
                    model.addPhotos(ids, person: who, takenAt: when, logID: logID, illnessID: illnessID)
                }
                Haptics.success()
                model.toast = who == .me ? tr("Snap! It's in your file.") : tr("Snap! It's in %@'s file.", model.name(for: who))
            }
            dismiss()
        }
    }
}

/// The system camera, for one photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.onClose()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onClose()
        }
    }
}

/// Photos full screen, one page each, with who and when, share and delete.
struct PhotoViewer: View {
    let focus: PhotoFocus
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID
    @State private var confirmDelete = false

    init(focus: PhotoFocus) {
        self.focus = focus
        _selection = State(initialValue: focus.start)
    }

    /// The photos still in the journal, so a deleted one leaves the pages.
    private var photos: [PatientPhoto] {
        focus.ids.compactMap { id in model.data.photos.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    ZoomablePhoto(id: photo.id)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                caption
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Close"))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: PhotoStore.url(for: selection)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(tr("Delete"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(tr("Delete this photo?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(tr("Delete"), role: .destructive) {
                    delete()
                }
                Button(tr("Cancel"), role: .cancel) {}
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var caption: some View {
        if let photo = photos.first(where: { $0.id == selection }) {
            VStack(spacing: 2) {
                Text(title(photo))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(photo.takenAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    /// Who, with what, and which day of it.
    private func title(_ photo: PatientPhoto) -> String {
        var parts = [model.name(for: photo.person)]
        if let germ = model.germ(of: photo) { parts.append(germ.illness.value) }
        if let day = model.sickDay(of: photo) { parts.append(tr("Day %lld", day)) }
        return parts.joined(separator: " · ")
    }

    private func delete() {
        let remaining = photos.filter { $0.id != selection }
        let gone = selection
        if let next = remaining.first {
            selection = next.id
        }
        model.deletePhoto(gone)
        if remaining.isEmpty { dismiss() }
    }
}

/// One photo that pinches to zoom, pans once zoomed, and toggles zoom on a double tap.
private struct ZoomablePhoto: View {
    let id: UUID
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var settled: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var dragged = CGSize.zero

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(MagnifyGesture()
            .onChanged { value in
                scale = min(4, max(1, settled * value.magnification))
            }
            .onEnded { _ in
                settled = scale
                if scale <= 1 { reset() }
            })
        .gesture(DragGesture()
            .onChanged { value in
                offset = CGSize(width: dragged.width + value.translation.width,
                                height: dragged.height + value.translation.height)
            }
            .onEnded { _ in
                dragged = offset
            }, including: scale > 1 ? .all : .none)
        .onTapGesture(count: 2) {
            withAnimation(Tempo.quick) {
                if scale > 1 {
                    reset()
                } else {
                    scale = 2.5
                    settled = 2.5
                }
            }
        }
        .task {
            if image == nil { image = PhotoStore.image(id) }
        }
        .accessibilityLabel(tr("Photo"))
    }

    private func reset() {
        scale = 1
        settled = 1
        offset = .zero
        dragged = .zero
    }
}
