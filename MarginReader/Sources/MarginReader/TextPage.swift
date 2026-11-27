/// The page that shows a document as its text, exactly as written.
enum TextPage {
    static func html(_ text: String, title: String) -> String {
        // The parser drops one newline right after <pre>, so the text starts on the line after it
        // and a blank first line survives.
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src \(ReaderScheme.appURL(""))">
        <title>\(escaped(title))</title>
        <link rel="stylesheet" href="\(ReaderScheme.appURL("text.css"))">
        </head>
        <body><pre class="text">
        \(escaped(text))</pre></body>
        </html>
        """
    }

    /// `text` with the characters that HTML would read as markup replaced by their references.
    static func escaped(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            default: escaped.append(character)
            }
        }
        return escaped
    }
}
