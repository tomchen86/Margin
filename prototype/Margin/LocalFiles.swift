import Foundation
import UniformTypeIdentifiers
import WebKit

/// Documents and everything they reference (images, CSS, linked pages) are served
/// through a custom `margin://` scheme. Requests are answered in the app process,
/// which holds the security-scoped access — the WebContent process never needs it.
nonisolated enum LocalScheme {
    static let name = "margin"
    /// `margin://file/<absolute path>`: files on disk.
    static let fileHost = "file"
    /// `margin://app/<name>`: the reader's own scripts, styles and fonts.
    static let appHost = "app"

    static func url(for fileURL: URL, source: Bool = false) -> URL {
        var components = URLComponents()
        components.scheme = name
        components.host = fileHost
        components.path = fileURL.path(percentEncoded: false)
        if source { components.query = "source" }
        return components.url!
    }

    static func isAppResource(_ url: URL) -> Bool {
        url.host() == appHost
    }

    static func fileURL(for url: URL) -> URL {
        URL(filePath: url.path(percentEncoded: false))
    }

    static func isSource(_ url: URL) -> Bool {
        url.query == "source"
    }
}

/// Builds the response for any file a page asks for.
nonisolated struct DocumentLoader: Sendable {
    let documentURL: URL
    let documentData: Data
    let documentKind: DocumentKind

    func response(for fileURL: URL, source: Bool) throws -> (data: Data, mimeType: String) {
        let isDocument = Paths.normalized(fileURL) == Paths.normalized(documentURL)
        #if targetEnvironment(simulator)
        if !isDocument { try SandboxSimulation.checkReadable(fileURL) }
        #endif
        // The opened document is already in memory; everything else is read on demand.
        let data = isDocument ? documentData : try Data(contentsOf: fileURL)
        let title = fileURL.deletingPathExtension().lastPathComponent

        if source {
            return (page(ReaderPage.source(TextDecoding.string(from: data), title: title)), "text/html")
        }
        switch isDocument ? documentKind : Self.pageKind(of: fileURL) {
        case .markdown?:
            return (page(ReaderPage.markdown(TextDecoding.string(from: data), title: title)), "text/html")
        case .html?:
            return (page(ReaderPage.html(TextDecoding.string(from: data))), "text/html")
        case .plainText?:
            return (page(ReaderPage.plainText(TextDecoding.string(from: data), title: title)), "text/html")
        case nil:
            let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            return (data, mimeType ?? "application/octet-stream")
        }
    }

    /// Linked Markdown/HTML files open as pages; anything else is a raw resource.
    private static func pageKind(of url: URL) -> DocumentKind? {
        switch DocumentKind(fileURL: url) {
        case .markdown: .markdown
        case .html: .html
        case .plainText: nil
        }
    }

    private func page(_ html: String) -> Data { Data(html.utf8) }
}

/// The reader's bundled scripts, styles and fonts, served at `margin://app/<name>`.
nonisolated enum AppResources {
    static func response(for url: URL) throws -> (data: Data, mimeType: String) {
        // Only the bare file name is looked up, so a request can't reach outside the bundle's resources.
        let name = url.lastPathComponent
        guard let fileURL = Bundle.main.url(forResource: name, withExtension: nil) else {
            throw URLError(.fileDoesNotExist)
        }
        return (try Data(contentsOf: fileURL), mimeType(forExtension: fileURL.pathExtension))
    }

    private static func mimeType(forExtension pathExtension: String) -> String {
        switch pathExtension {
        case "js": "text/javascript"
        case "css": "text/css"
        case "woff2": "font/woff2"
        default: UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}

nonisolated struct LocalSchemeHandler: URLSchemeHandler {
    let loader: DocumentLoader
    /// Called with files the sandbox wouldn't let us read, so the UI can ask for folder access.
    let onUnreadable: @Sendable (URL) -> Void

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        let loader = loader
        let onUnreadable = onUnreadable
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                guard let url = request.url else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                do {
                    let (data, mimeType) = try Self.response(for: url, loader: loader, onUnreadable: onUnreadable)
                    let response = URLResponse(
                        url: url,
                        mimeType: mimeType,
                        expectedContentLength: data.count,
                        textEncodingName: mimeType.hasPrefix("text/") ? "utf-8" : nil
                    )
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

    private static func response(
        for url: URL,
        loader: DocumentLoader,
        onUnreadable: @Sendable (URL) -> Void
    ) throws -> (data: Data, mimeType: String) {
        if LocalScheme.isAppResource(url) {
            return try AppResources.response(for: url)
        }
        let fileURL = LocalScheme.fileURL(for: url)
        do {
            return try loader.response(for: fileURL, source: LocalScheme.isSource(url))
        } catch {
            onUnreadable(fileURL)
            throw error
        }
    }
}

/// HTML wrappers that give Markdown and text the native reader look.
nonisolated enum ReaderPage {
    static let css: String = Bundle.main.url(forResource: "Reader", withExtension: "css")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    /// Markdown is converted in the page by `render.js` (markdown-it, KaTeX, highlight.js).
    /// The policy lets only the app's own scripts run: anything the document itself
    /// contains — `<script>`, `onerror=`, local or inline frames — is blocked, and no
    /// script can fetch files. Web content loads as in a browser: images, media, and
    /// https iframes, which have their own origin and can't read `margin://` responses.
    static func markdown(_ text: String, title: String) -> String {
        let app = "\(LocalScheme.name)://\(LocalScheme.appHost)/"
        let policy = [
            "default-src 'none'",
            "script-src \(app)",
            "style-src \(app) 'unsafe-inline'",
            "font-src \(app)",
            "img-src \(LocalScheme.name): data: https: http:",
            "media-src \(LocalScheme.name): https: http:",
            "frame-src https:",
        ].joined(separator: "; ")
        return """
            <!doctype html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="\(policy)">
            <title>\(HTML.escape(title))</title>
            <link rel="stylesheet" href="\(app)katex.min.css">
            <link rel="stylesheet" href="\(app)highlight-light.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="\(app)highlight-dark.min.css" media="(prefers-color-scheme: dark)">
            <style>\(css)</style>
            </head>
            <body><article></article>
            <script type="application/json" id="margin-source">\(jsonLiteral(text))</script>
            <script src="\(app)markdown-it.min.js"></script>
            <script src="\(app)markdown-it-footnote.min.js"></script>
            <script src="\(app)katex.min.js"></script>
            <script src="\(app)highlight.min.js"></script>
            <script src="\(app)render.js"></script>
            </body>
            </html>
            """
    }

    /// The Markdown source as a JSON string. `<` is escaped so the text can never
    /// close the `<script>` element it sits in.
    private static func jsonLiteral(_ text: String) -> String {
        let data = (try? JSONEncoder().encode(text)) ?? Data(#""""#.utf8)
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "<", with: #"<"#)
    }

    static func plainText(_ text: String, title: String) -> String {
        wrap("<pre class=\"plain\">\(HTML.escape(text))</pre>", title: title)
    }

    static func source(_ text: String, title: String) -> String {
        wrap("<pre class=\"source\">\(HTML.escape(text))</pre>", title: title)
    }

    /// HTML files are shown as their authors wrote them. The only change: pages
    /// without a viewport tag would render at desktop width, so one is added.
    static func html(_ text: String) -> String {
        guard text.range(of: "name=\"viewport\"", options: .caseInsensitive) == nil,
              text.range(of: "name=viewport", options: .caseInsensitive) == nil
        else { return text }
        let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        if let head = text.range(of: #"<head[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
            return text.replacingCharacters(in: head, with: text[head] + viewport)
        }
        if let html = text.range(of: #"<html[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
            return text.replacingCharacters(in: html, with: text[html] + "<head>\(viewport)</head>")
        }
        return viewport + text
    }

    private static func wrap(_ body: String, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="script-src 'none'">
        <title>\(HTML.escape(title))</title>
        <style>\(css)</style>
        </head>
        <body><article>
        \(body)
        </article></body>
        </html>
        """
    }
}
