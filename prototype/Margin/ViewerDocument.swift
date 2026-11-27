import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

nonisolated enum DocumentKind: Sendable {
    case markdown, html, plainText

    init(fileURL: URL) {
        switch fileURL.pathExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd", "mkdn": self = .markdown
        case "html", "htm", "xhtml": self = .html
        default: self = .plainText
        }
    }
}

/// Read-only document. The system document browser (DocumentGroup) handles
/// opening, recents and iCloud — the app doesn't manage files itself.
nonisolated struct ViewerDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.markdownText, .html, .plainText]

    let data: Data
    let contentType: UTType

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    func kind(fileURL: URL?) -> DocumentKind {
        if contentType.conforms(to: .html) { return .html }
        if contentType.conforms(to: .markdownText) { return .markdown }
        return fileURL.map(DocumentKind.init(fileURL:)) ?? .plainText
    }
}
