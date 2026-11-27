import Foundation

/// How the reader shows a document.
enum DocumentKind: Equatable {
    /// Rendered by the page's bundled markdown-it (ADR-0002).
    case markdown
    /// Its text, exactly as written.
    case text

    /// The extensions DOCUMENTS-1.1 opens as Markdown, in any case.
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn"]

    init(documentURL: URL) {
        self = Self.markdownExtensions.contains(documentURL.pathExtension.lowercased()) ? .markdown : .text
    }
}
