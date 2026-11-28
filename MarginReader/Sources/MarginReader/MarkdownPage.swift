import Foundation

/// The page that shows a Markdown document: the source embedded as a JSON string, rendered in the
/// page by the bundled markdown-it, KaTeX for math, highlight.js for code, and `render.js` (ADR-0002).
enum MarkdownPage {
    /// Only the app's own scripts, styles, and fonts load; a document's scripts, event handlers,
    /// `javascript:` links, objects, and frames other than `https:` don't. Images next to the
    /// document load through `margin://file/`; web images and media load as in a browser. `style` attributes and `<style>` elements apply.
    static let contentSecurityPolicy = [
        "default-src 'none'",
        "script-src \(ReaderScheme.appURL(""))",
        "style-src \(ReaderScheme.appURL("")) 'unsafe-inline'",
        "font-src \(ReaderScheme.appURL(""))",
        "img-src \(ReaderScheme.fileURL) https: http: data:",
        "media-src https: http:",
        "frame-src https:",
        "base-uri 'none'",
        "form-action 'none'",
    ].joined(separator: "; ")

    static func html(_ markdown: String, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
        <title>\(TextPage.escaped(title))</title>
        <link rel="stylesheet" href="\(ReaderScheme.appURL("katex.min.css"))">
        <link rel="stylesheet" href="\(ReaderScheme.appURL("github.min.css"))" media="(prefers-color-scheme: light)">
        <link rel="stylesheet" href="\(ReaderScheme.appURL("github-dark.min.css"))" media="(prefers-color-scheme: dark)">
        <link rel="stylesheet" href="\(ReaderScheme.appURL("markdown.css"))">
        </head>
        <body><article></article>
        <script type="application/json" id="source">\(jsonString(markdown))</script>
        <script src="\(ReaderScheme.appURL("markdown-it.min.js"))"></script>
        <script src="\(ReaderScheme.appURL("markdown-it-footnote.min.js"))"></script>
        <script src="\(ReaderScheme.appURL("katex.min.js"))"></script>
        <script src="\(ReaderScheme.appURL("highlight.min.js"))"></script>
        <script src="\(ReaderScheme.appURL("render.js"))"></script>
        </body>
        </html>
        """
    }

    /// `text` as a JSON string with no `<` in it, so no part of the text can end or reopen the
    /// script element that holds it.
    static func jsonString(_ text: String) -> String {
        var json = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": json += "\\\""
            case "\\": json += "\\\\"
            case "\n": json += "\\n"
            case "\r": json += "\\r"
            case "\t": json += "\\t"
            case "<", "\u{2028}", "\u{2029}",
                _ where scalar.value < 0x20:
                json += String(format: "\\u%04x", scalar.value)
            default: json.unicodeScalars.append(scalar)
            }
        }
        return json + "\""
    }
}
