import Foundation

/// The page that shows an HTML document as its author wrote it (HTML-1.1): the document itself,
/// with nothing of the reader's own, decoded as a browser would decode the file.
enum HTMLPage {
    /// The bytes to serve for an HTML document and the text encoding to serve them in.
    ///
    /// A document without a byte-order mark that declares its charset is served as it is, so
    /// WebKit decodes it in that charset (HTML-6.1). Any other document is decoded by
    /// ``TextDecoding`` and served as UTF-8, which then also outranks a later declaration.
    static func page(_ document: Data) -> (data: Data, textEncoding: String?) {
        if TextDecoding.decodingByteOrderMark(document) == nil, declaresCharset(document) {
            return (withViewport(document), nil)
        }
        return (withViewport(Data(TextDecoding.string(from: document).utf8)), "utf-8")
    }

    /// Lays a document without a viewport tag out as wide as the screen, unzoomed (HTML-2.1).
    static let viewport = #"<meta name="viewport" content="width=device-width, initial-scale=1">"#

    /// How far into a document a browser looks for a charset declaration.
    static let prescanLength = 1024

    /// Whether the first 1024 bytes hold `<meta charset>` or a `<meta http-equiv="Content-Type">`
    /// that names a charset, as a browser's prescan finds them.
    static func declaresCharset(_ document: Data) -> Bool {
        let head = latin1(document.prefix(prescanLength))
        return head.matches(of: /(?i)<meta\b[^>]*>/).contains { match in
            let tag = match.output
            if tag.contains(/(?i)\scharset\s*=/) && !tag.contains(/(?i)\bcontent\s*=/) {
                return true
            }
            return tag.contains(/(?i)\bhttp-equiv\s*=\s*["']?\s*content-type/)
                && tag.contains(/(?i)\bcontent\s*=\s*["']?[^"'>]*\bcharset\s*=/)
        }
    }

    /// `document` with `viewport` right after its doctype, or at its start when it has none,
    /// unless it already has a viewport tag. After the doctype, the tag doesn't change the
    /// document's mode, and the parser puts it in the document's head.
    static func withViewport(_ document: Data) -> Data {
        if latin1(document).contains(/(?i)<meta\b[^>]*\bname\s*=\s*["']?\s*viewport\b/) {
            return document
        }
        let head = latin1(document.prefix(prescanLength))
        let offset =
            head.firstMatch(of: /(?i)<!doctype\b[^>]*>/).map {
                head.unicodeScalars.distance(from: head.startIndex, to: $0.range.upperBound)
            } ?? 0
        var page = Data(document.prefix(offset))
        page.append(Data(viewport.utf8))
        page.append(document.dropFirst(offset))
        return page
    }

    /// The bytes as ISO Latin-1 text: one character per byte, so offsets are byte offsets and
    /// ASCII markup reads the same in any ASCII-compatible encoding.
    private static func latin1(_ bytes: Data) -> String {
        String(String.UnicodeScalarView(bytes.map { Unicode.Scalar($0) }))
    }
}
