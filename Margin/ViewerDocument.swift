import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// Markdown, as iOS knows it.
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    /// Markdown files with the extensions iOS leaves out of ``markdown``: `.markdown`, `.mdown`, `.mkd`, `.mkdn`.
    static let markdownExtensions = UTType(
        importedAs: "io.github.tomchen86.margin.markdown", conformingTo: .markdown)
}

/// A document the app opens, read only. The document browser finds and opens it; the reader reads
/// it from its file.
nonisolated struct ViewerDocument: FileDocument {
    /// Matched by conformance, so formats built on these types open too, such as SVG (XML) and
    /// GeoJSON (JSON), and source code and logs (plain text).
    static let readableContentTypes: [UTType] = [
        .markdown, .markdownExtensions, .html, .json, .yaml, .xml, .plainText,
    ]
    static let writableContentTypes: [UTType] = []

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isRegularFile else { throw CocoaError(.fileReadCorruptFile) }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Margin never writes to a document.
        throw CocoaError(.featureUnsupported)
    }
}
