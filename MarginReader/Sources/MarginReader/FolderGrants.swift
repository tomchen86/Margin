import Foundation
import Synchronization

/// The folders the owner granted Margin access to, kept as bookmarks across launches (ADR-0004).
/// A grant covers its folder and every subfolder, for every document, until Margin is deleted.
public final class FolderGrants: Sendable {
    /// The grants every reader uses.
    public static let shared = FolderGrants(defaultsKey: "grantedFolderBookmarks")

    private let defaultsKey: String
    /// The granted folders, each accessed for as long as the app runs.
    private let folders: Mutex<[URL]>

    init(defaultsKey: String) {
        self.defaultsKey = defaultsKey
        var resolved: [URL] = []
        for bookmark in UserDefaults.standard.array(forKey: defaultsKey) as? [Data] ?? [] {
            var stale = false
            guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { continue }
            _ = folder.startAccessingSecurityScopedResource()
            resolved.append(folder)
        }
        folders = Mutex(resolved)
    }

    /// Keeps access to `folder`, which the owner chose in the folder picker, now and after relaunching.
    public func grant(_ folder: URL) throws {
        _ = folder.startAccessingSecurityScopedResource()
        let bookmark = try folder.bookmarkData()
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [Data] ?? []
        UserDefaults.standard.set(saved + [bookmark], forKey: defaultsKey)
        folders.withLock { $0.append(folder) }
    }

    /// Whether a granted folder holds `file`, directly or in a subfolder.
    public func covers(_ file: URL) -> Bool {
        folders.withLock { $0.contains { Self.folder($0, holds: file) } }
    }

    /// Whether `file` is `folder` itself or lies anywhere below it.
    static func folder(_ folder: URL, holds file: URL) -> Bool {
        let folder = canonicalComponents(folder)
        return canonicalComponents(file).starts(with: folder)
    }

    /// The path's components, with `.`, `..`, symbolic links, and a leading `/private` resolved,
    /// so two spellings of one place compare equal.
    static func canonicalComponents(_ url: URL) -> [String] {
        url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    }
}
