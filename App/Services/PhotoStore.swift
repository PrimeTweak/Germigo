import ImageIO
import UIKit

/// The household's photos, as protected JPEG files next to the journal. Nothing here leaves the phone.
enum PhotoStore {
    /// Longest side kept: enough to show a rash to a doctor, small enough for backups.
    static let longestSide: CGFloat = 2048

    private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Germigo/Photos", isDirectory: true)
    }

    static func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".jpg")
    }

    /// Shrinks and writes a picture; nil when it could not be written.
    static func save(_ image: UIImage) -> UUID? {
        guard let data = jpeg(image) else { return nil }
        let id = UUID()
        return write(data, id: id) ? id : nil
    }

    @discardableResult
    static func write(_ data: Data, id: UUID) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(for: id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// The JPEG files of these photos, for a backup.
    static func files(for ids: [UUID]) -> [UUID: Data] {
        var files: [UUID: Data] = [:]
        for id in ids {
            if let data = try? Data(contentsOf: url(for: id)) { files[id] = data }
        }
        return files
    }

    static func image(_ id: UUID) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    /// A small copy for thumbnails, decoded once and kept in memory.
    static func thumbnail(_ id: UUID, side: CGFloat) -> UIImage? {
        let key = (id.uuidString + "-" + String(Int(side))) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil),
              let image = downsample(source, maxPixels: side * 3) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// A picked file decoded straight to the kept size, without holding the full picture in memory.
    static func image(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsample(source, maxPixels: longestSide)
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        cache.removeAllObjects()
    }

    /// Removes every file that no photo of the journal points to.
    static func keepOnly(_ ids: Set<UUID>) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names {
            let stem = (name as NSString).deletingPathExtension
            if let id = UUID(uuidString: stem), ids.contains(id) { continue }
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        cache.removeAllObjects()
    }

    static func eraseAll() {
        try? FileManager.default.removeItem(at: directory)
        cache.removeAllObjects()
    }

    private static func downsample(_ source: CGImageSource, maxPixels: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func jpeg(_ image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, longestSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
