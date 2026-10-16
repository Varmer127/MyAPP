import UIKit

/// Body photos live only here: in the app's own private folder (not the shared container the widget reads),
/// encrypted by iOS whenever the phone is locked, kept out of iCloud and device backups,
/// and never written to the photo library.
enum PhotoVault {
    private static let folderName = "BodyPhotos"
    private static let jpegQuality = 0.8

    private static var folder: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        var url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                     attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return url
    }

    /// Stores a photo and returns its file name, or nil if it could not be written.
    static func save(_ image: UIImage) -> String? {
        guard let folder, let data = image.jpegData(compressionQuality: jpegQuality) else { return nil }
        let name = UUID().uuidString + ".jpg"
        var url = folder.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.completeFileProtection, .atomic])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        guard let folder else { return nil }
        return UIImage(contentsOfFile: folder.appendingPathComponent(name).path)
    }

    static func delete(_ name: String) {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }

    /// Everything, for the developer reset.
    static func deleteAll() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
