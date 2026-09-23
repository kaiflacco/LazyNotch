import AppKit
import Foundation

/// Model representing a staged file in LazyShelf.
public struct LazyShelfItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let sizeString: String
    public let icon: NSImage

    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)

        // Calculate friendly file size
        if let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
           let isDir = resources.isDirectory, !isDir,
           let size = resources.fileSize {
            self.sizeString = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } else {
            self.sizeString = "Folder"
        }
    }

    public static func == (lhs: LazyShelfItem, rhs: LazyShelfItem) -> Bool {
        lhs.id == rhs.id
    }
}
