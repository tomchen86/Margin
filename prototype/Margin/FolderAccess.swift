import Foundation
import Observation

/// Folders the user has granted access to, remembered as security-scoped bookmarks.
///
/// Opening a single file from the Files app only grants access to that file, so
/// images next to it (`images/a.png`, `../assets/b.png`) can't be read. Granting a
/// folder once fixes that for every document inside it, across launches.
@Observable
final class FolderAccess {
    private(set) var folders: [URL] = []

    private static let defaultsKey = "grantedFolderBookmarks"

    init() {
        let stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Data] ?? []
        var kept: [Data] = []
        for bookmark in stored {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
                  url.startAccessingSecurityScopedResource()
            else { continue }
            remember(url)
            kept.append(isStale ? ((try? url.bookmarkData()) ?? bookmark) : bookmark)
        }
        UserDefaults.standard.set(kept, forKey: Self.defaultsKey)
    }

    func grant(_ folder: URL) throws {
        guard folder.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        let bookmark = try folder.bookmarkData()
        remember(folder)
        var stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Data] ?? []
        stored.append(bookmark)
        UserDefaults.standard.set(stored, forKey: Self.defaultsKey)
    }

    private func remember(_ folder: URL) {
        folders.append(folder)
        #if targetEnvironment(simulator)
        SandboxSimulation.allow(folder)
        #endif
    }

    /// Whether `url` can already be read: inside the app's own container or a granted folder.
    func covers(_ url: URL) -> Bool {
        let roots = folders + [URL.homeDirectory]
        return roots.contains { Paths.isInside(url, $0) }
    }
}

nonisolated enum Paths {
    static func normalized(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    static func isInside(_ url: URL, _ folder: URL) -> Bool {
        let path = normalized(url)
        let root = normalized(folder)
        return path == root || path.hasPrefix(root == "/" ? root : root + "/")
    }

    /// The deepest folder containing every given file.
    static func commonFolder(of urls: [URL]) -> URL? {
        let folders = urls.map { normalized($0.deletingLastPathComponent()).split(separator: "/") }
        guard var common = folders.first else { return nil }
        for components in folders.dropFirst() {
            common = Array(zip(common, components).prefix { $0 == $1 }.map(\.0))
        }
        return URL(filePath: "/" + common.joined(separator: "/"), directoryHint: .isDirectory)
    }
}
