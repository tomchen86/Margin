import Foundation
import UniformTypeIdentifiers
import WebKit

/// The `margin://` URLs a reader's page loads (ADR-0004).
///
/// - `margin://file/<absolute path>`: the document's page: rendered Markdown, or the text as written.
/// - `margin://app/<name>`: a file bundled in `Web/`, such as a stylesheet or the Markdown renderer.
enum ReaderScheme {
    static let name = "margin"
    static let fileHost = "file"
    static let appHost = "app"

    static func pageURL(for documentURL: URL) -> URL {
        var components = URLComponents()
        components.scheme = name
        components.host = fileHost
        components.path = documentURL.standardizedFileURL.path(percentEncoded: false)
        return components.url!
    }

    static func isPage(_ url: URL, of documentURL: URL) -> Bool {
        url.host() == fileHost
            && URL(filePath: url.path(percentEncoded: false)).standardizedFileURL == documentURL.standardizedFileURL
    }

    static func appURL(_ name: String) -> URL {
        URL(string: "\(Self.name)://\(appHost)/\(name)")!
    }
}

/// Answers the page's `margin://` requests in the process that shows it, which can read the document.
struct ReaderSchemeHandler: URLSchemeHandler {
    let documentURL: URL

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        let documentURL = documentURL
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    guard let url = request.url else { throw URLError(.badURL) }
                    let (data, mimeType) = try Self.contents(of: url, documentURL: documentURL)
                    let response = URLResponse(
                        url: url, mimeType: mimeType, expectedContentLength: data.count,
                        textEncodingName: mimeType.hasPrefix("text/") ? "utf-8" : nil)
                    continuation.yield(.response(response))
                    continuation.yield(.data(data))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func contents(of url: URL, documentURL: URL) throws -> (data: Data, mimeType: String) {
        switch url.host() {
        case ReaderScheme.appHost:
            return try bundledFile(url.path(percentEncoded: false))
        case ReaderScheme.fileHost where ReaderScheme.isPage(url, of: documentURL):
            let text = String(decoding: try readDocument(documentURL), as: UTF8.self)
            let title = documentURL.lastPathComponent
            let page =
                switch DocumentKind(documentURL: documentURL) {
                case .markdown: MarkdownPage.html(text, title: title)
                case .text: TextPage.html(text, title: title)
                }
            return (Data(page.utf8), "text/html")
        default:
            throw URLError(.fileDoesNotExist)
        }
    }

    /// Reads the document, inside its security scope when it has one. Margin only ever reads it.
    private static func readDocument(_ documentURL: URL) throws -> Data {
        let scoped = documentURL.startAccessingSecurityScopedResource()
        defer { if scoped { documentURL.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: documentURL)
    }

    /// A file directly in `Web/`; any other path, such as one with `..` or a subfolder, is not found.
    private static func bundledFile(_ path: String) throws -> (data: Data, mimeType: String) {
        let name = String(path.dropFirst())
        guard path.hasPrefix("/"), !name.isEmpty, !name.contains("/"), name != "..",
            let file = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Web")
        else { throw URLError(.fileDoesNotExist) }
        let mimeType = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return (try Data(contentsOf: file), mimeType)
    }
}
