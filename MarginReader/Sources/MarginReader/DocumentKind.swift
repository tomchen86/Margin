import Foundation

/// How the reader shows a document.
enum DocumentKind: Equatable {
    /// Rendered by the page's bundled markdown-it (ADR-0002).
    case markdown
    /// As its author wrote it, with its own styles and scripts (HTML-1.1).
    case html
    /// Its text, exactly as written.
    case text

    /// The extensions DOCUMENTS-1.1 opens as Markdown, in any case.
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn"]
    /// The extensions DOCUMENTS-1.1 opens as HTML, in any case.
    static let htmlExtensions: Set<String> = ["html", "htm"]

    init(documentURL: URL) {
        let pathExtension = documentURL.pathExtension.lowercased()
        if Self.markdownExtensions.contains(pathExtension) {
            self = .markdown
        } else if Self.htmlExtensions.contains(pathExtension) {
            self = .html
        } else {
            self = .text
        }
    }
}
