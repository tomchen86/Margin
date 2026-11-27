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
        page = WebPage()
    }

    /// Loads the document into ``page`` and returns once the page shows it.
    public func load() async throws {}
}
