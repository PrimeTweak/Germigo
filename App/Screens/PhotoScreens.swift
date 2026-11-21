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
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
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
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    people
                    VStack(spacing: 0) {
                        row(tr("For")) {
                            Picker(tr("For"), selection: $link) {
                                ForEach(options, id: \.self) { option in
                                    Text(option.title).tag(option.link)
                                }
                                Text(tr("Nothing in particular")).tag(PhotoLink.unlinked)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(palette.inkSecondary)
                        }
                        Divider()
                            .padding(.leading, 16)
                        row(tr("Taken")) {
                            DatePicker(tr("Taken"), selection: $takenAt, in: ...Date())
                                .labelsHidden()
                        }
                    }
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    Text(tr("Photos stay on this phone and in your backups. Germigo never uploads them."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Save"))
                    .tint(palette.ink)
                    .disabled(images.isEmpty || saving)
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
                        withAnimation(.snappy) {
                            images = []
                            picked = []
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .padding(12)
                    .accessibilityLabel(tr("Start over"))
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(height: 300)
    }

    private var people: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(members, id: \.self) { member in
                    let selected = member == person
                    Button {
                        withAnimation(.snappy) {
                            person = member
                        }
                    } label: {
                        HStack(spacing: 6) {
                            BuddyView(look: model.look(of: member), sick: true, size: 28)
                            Text(model.name(for: member))
                                .font(.callout.weight(.semibold))
                        }
                        .foregroundStyle(selected ? palette.background : palette.ink)
                        .padding(.leading, 6)
                        .padding(.trailing, 14)
                        .frame(height: 44)
                        .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func row<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(palette.ink)
            Spacer(minLength: 8)
            value()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private func title(of entry: DayEntry) -> String {
        let illness = model.catalog.germ(entry.germID)?.illness.value ?? entry.germID
        let start = Calendar.current.date(byAdding: .day, value: 1 - entry.dayNumber, to: takenAt) ?? takenAt
        return tr("%1$@, since %2$@", illness, start.formatted(.dateTime.month(.abbreviated).day()))
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
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
                Text(model.name(for: photo.person))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail(photo))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func detail(_ photo: PatientPhoto) -> String {
        let when = photo.takenAt.formatted(date: .abbreviated, time: .shortened)
        let germID = photo.logID.flatMap { id in model.data.logs.first { $0.id == id }?.germID }
            ?? photo.illnessID.flatMap { id in model.data.kidIllnesses.first { $0.id == id }?.germID }
        guard let illness = germID.flatMap({ model.catalog.germ($0) })?.illness.value else { return when }
        return illness + " · " + when
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
            withAnimation(.snappy) {
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
