import Foundation
import UniformTypeIdentifiers
import WebKit

/// The `margin://` URLs a reader's page loads (ADR-0004).
///
/// - `margin://file/<absolute path>`: the document's page, rendered Markdown or the text as written,
///   or a file next to it that the page loads, such as an image, as it is on disk.
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
        url.host() == fileHost && file(for: url).standardizedFileURL == documentURL.standardizedFileURL
    }

    /// The file a `margin://file/` URL names; a query or fragment after the name is ignored.
    static func file(for url: URL) -> URL {
        URL(filePath: url.path(percentEncoded: false))
    }

    /// The source of every file a page loads from disk, for a page's policy.
    static let fileURL = "\(name)://\(fileHost)/"

    static func appURL(_ name: String) -> URL {
        URL(string: "\(Self.name)://\(appHost)/\(name)")!
    }
}

/// Answers the page's `margin://` requests in the process that shows it, which holds the access to
/// the document and the granted folders.
struct ReaderSchemeHandler: URLSchemeHandler {
    let documentURL: URL
    let grants: FolderGrants
    /// Called with each file the page tried to load that iOS keeps out of the app's reach.
    let outOfReach: @Sendable (URL) -> Void

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        let documentURL = documentURL
        let grants = grants
        let outOfReach = outOfReach
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    guard let url = request.url else { throw URLError(.badURL) }
                    let (data, mimeType): (Data, String)
                    do {
                        (data, mimeType) = try Self.contents(of: url, documentURL: documentURL, grants: grants)
                    } catch let error where url.host() == ReaderScheme.fileHost && FileReading.isOutOfReach(error) {
                        outOfReach(ReaderScheme.file(for: url))
                        throw error
                    }
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

    static func contents(
        of url: URL, documentURL: URL, grants: FolderGrants
    ) throws -> (data: Data, mimeType: String) {
        switch url.host() {
        case ReaderScheme.appHost:
            return try bundledFile(url.path(percentEncoded: false))
        case ReaderScheme.fileHost where ReaderScheme.isPage(url, of: documentURL):
            let document = try FileReading.data(of: documentURL, document: documentURL, grants: grants)
            let text = String(decoding: document, as: UTF8.self)
            let title = documentURL.lastPathComponent
            let page =
                switch DocumentKind(documentURL: documentURL) {
                case .markdown: MarkdownPage.html(text, title: title)
                case .text: TextPage.html(text, title: title)
                }
            return (Data(page.utf8), "text/html")
        case ReaderScheme.fileHost:
            // A file the page loads, such as an image next to the document, read only.
            let file = ReaderScheme.file(for: url)
            return (try FileReading.data(of: file, document: documentURL, grants: grants), mimeType(of: file))
        default:
            throw URLError(.fileDoesNotExist)
        }
    }

    private static func mimeType(of file: URL) -> String {
        UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// A file directly in `Web/`; any other path, such as one with `..` or a subfolder, is not found.
    private static func bundledFile(_ path: String) throws -> (data: Data, mimeType: String) {
        let name = String(path.dropFirst())
        guard path.hasPrefix("/"), !name.isEmpty, !name.contains("/"), name != "..",
            let file = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Web")
        else { throw URLError(.fileDoesNotExist) }
        return (try Data(contentsOf: file), mimeType(of: file))
    }
}
