import Foundation
import Observation
import WebKit

/// Shows one document, read from its file, in a `WebPage`.
///
/// The app and the Quick Look extension put ``page`` in a `WebView`.
@MainActor
@Observable
public final class Reader {
    /// The file this reader shows.
    public let documentURL: URL
    /// The page that shows the document.
    public let page: WebPage

    private let grants: FolderGrants
    private let outOfReach: OutOfReachFiles

    public convenience init(documentURL: URL) {
        self.init(documentURL: documentURL, grants: .shared)
    }

    init(documentURL: URL, grants: FolderGrants) {
        self.documentURL = documentURL
        self.grants = grants
        let outOfReach = OutOfReachFiles()
        self.outOfReach = outOfReach
        var configuration = WebPage.Configuration()
        if let scheme = URLScheme(ReaderScheme.name) {
            configuration.urlSchemeHandlers[scheme] = ReaderSchemeHandler(
                documentURL: documentURL, grants: grants,
                outOfReach: { file in Task { @MainActor in outOfReach.add(file) } })
        }
        // A Markdown page runs the app's renderer, and its policy lets nothing else run; an HTML
        // page runs its own scripts; a page that shows a document's text has nothing to run.
        configuration.defaultNavigationPreferences.allowsContentJavaScript =
            DocumentKind(documentURL: documentURL) != .text
        page = WebPage(configuration: configuration)
    }

    /// Loads the document into ``page`` and returns once the page shows it.
    public func load() async throws {
        outOfReach.files = []
        for try await event in page.load(URLRequest(url: ReaderScheme.pageURL(for: documentURL)))
        where event == .finished {
            return
        }
    }

    /// The files the page tried to load since it last loaded that iOS keeps out of the app's reach.
    public var filesOutOfReach: [URL] {
        outOfReach.files.filter { !grants.covers($0) }
    }

    /// The folder to ask the owner for: the deepest one that holds the document and every file out
    /// of reach. Nil while nothing is out of reach.
    public var folderToOffer: URL? {
        Self.folder(holding: documentURL, and: filesOutOfReach)
    }

    nonisolated static func folder(holding document: URL, and files: [URL]) -> URL? {
        guard !files.isEmpty else { return nil }
        let folders = ([document] + files).map {
            FolderGrants.canonicalComponents($0.deletingLastPathComponent())
        }
        let common = folders.dropFirst().reduce(folders[0]) { common, folder in
            Array(zip(common, folder).prefix { $0 == $1 }.map(\.0))
        }
        return URL(filePath: NSString.path(withComponents: common), directoryHint: .isDirectory)
    }
}

/// The files a page found out of reach, collected on the main actor as the page's requests fail.
@MainActor
@Observable
final class OutOfReachFiles {
    var files: [URL] = []

    func add(_ file: URL) {
        if !files.contains(file) { files.append(file) }
    }
}
