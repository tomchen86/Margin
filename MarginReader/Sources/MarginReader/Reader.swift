import Foundation
import WebKit

/// Shows one document, read from its file, in a `WebPage`.
///
/// The app and the Quick Look extension put ``page`` in a `WebView`.
@MainActor
public final class Reader {
    /// The file this reader shows.
    public let documentURL: URL
    /// The page that shows the document.
    public let page: WebPage

    public init(documentURL: URL) {
        self.documentURL = documentURL
        var configuration = WebPage.Configuration()
        if let scheme = URLScheme(ReaderScheme.name) {
            configuration.urlSchemeHandlers[scheme] = ReaderSchemeHandler(documentURL: documentURL)
        }
        // A Markdown page runs the app's renderer, and its policy lets nothing else run; a page
        // that shows a document's text has nothing to run.
        configuration.defaultNavigationPreferences.allowsContentJavaScript =
            DocumentKind(documentURL: documentURL) == .markdown
        page = WebPage(configuration: configuration)
    }

    /// Loads the document into ``page`` and returns once the page shows it: its text as written
    /// when `showingSource` is true, otherwise the document itself.
    public func load(showingSource: Bool = false) async throws {
        for try await event in page.load(URLRequest(url: ReaderScheme.pageURL(for: documentURL)))
        where event == .finished {
            return
        }
    }
}
