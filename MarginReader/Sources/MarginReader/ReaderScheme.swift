import Foundation
import UniformTypeIdentifiers
import WebKit

/// The `margin://` URLs a reader's page loads (ADR-0004).
///
/// - `margin://file/<absolute path>`: the document's page, rendered Markdown, the HTML as written,
///   or the text as written; or a file next to it that the page loads, as it is on disk.
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
                    let resource: Resource
                    do {
                        resource = try Self.contents(of: url, documentURL: documentURL, grants: grants)
                    } catch let error where url.host() == ReaderScheme.fileHost && FileReading.isOutOfReach(error) {
                        outOfReach(ReaderScheme.file(for: url))
                        throw error
                    }
                    let response = URLResponse(
                        url: url, mimeType: resource.mimeType, expectedContentLength: resource.data.count,
                        textEncodingName: resource.textEncoding)
                    continuation.yield(.response(response))
                    continuation.yield(.data(resource.data))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// What the handler answers a request with.
    struct Resource {
        let data: Data
        let mimeType: String
        /// The encoding of a text resource, or nil to let WebKit find it, as a browser does for a file.
        let textEncoding: String?
    }

    static func contents(of url: URL, documentURL: URL, grants: FolderGrants) throws -> Resource {
        switch url.host() {
        case ReaderScheme.appHost:
            return try bundledFile(url.path(percentEncoded: false))
        case ReaderScheme.fileHost where ReaderScheme.isPage(url, of: documentURL):
            let document = try FileReading.data(of: documentURL, document: documentURL, grants: grants)
            let title = documentURL.lastPathComponent
            switch DocumentKind(documentURL: documentURL) {
            case .markdown:
                let page = MarkdownPage.html(TextDecoding.string(from: document), title: title)
                return Resource(data: Data(page.utf8), mimeType: "text/html", textEncoding: "utf-8")
            case .html:
                let (page, textEncoding) = HTMLPage.page(document)
                return Resource(data: page, mimeType: "text/html", textEncoding: textEncoding)
            case .text:
                let page = TextPage.html(TextDecoding.string(from: document), title: title)
                return Resource(data: Data(page.utf8), mimeType: "text/html", textEncoding: "utf-8")
            }
        case ReaderScheme.fileHost:
            // A file the page loads, such as an image, a stylesheet, or data next to the document,
            // read only and served as it is, so WebKit finds a text file's encoding as a browser does.
            let file = ReaderScheme.file(for: url)
            let data = try FileReading.data(of: file, document: documentURL, grants: grants)
            return Resource(data: data, mimeType: mimeType(of: file), textEncoding: nil)
        default:
            throw URLError(.fileDoesNotExist)
        }
    }

    private static func mimeType(of file: URL) -> String {
        UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// A file directly in `Web/`, or in `Web/fonts/`, where KaTeX's stylesheet looks for its fonts;
    /// any other path, such as one with `..` or another folder, is not found.
    private static func bundledFile(_ path: String) throws -> Resource {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        let folder = components.count == 2 && components.first == "fonts" ? "Web/fonts" : "Web"
        guard path.hasPrefix("/"), components.count == 1 || folder == "Web/fonts",
            let name = components.last.map(String.init), !name.isEmpty, name != ".", name != "..",
            let file = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: folder)
        else { throw URLError(.fileDoesNotExist) }
        let mimeType = mimeType(of: file)
        // The reader's own stylesheets and scripts are UTF-8.
        return Resource(
            data: try Data(contentsOf: file), mimeType: mimeType,
            textEncoding: mimeType.hasPrefix("text/") ? "utf-8" : nil)
    }
}
