import Foundation

/// Turns Markdown into HTML using only Foundation's built-in (cmark-gfm based) parser.
/// No third-party dependencies: block structure comes from `PresentationIntent`,
/// inline styling from `InlinePresentationIntent`.
nonisolated enum MarkdownRenderer {
    static func body(from markdown: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        // An image with empty alt text would produce no characters and therefore no run.
        // A zero-width placeholder keeps it in the attributed string.
        let source = markdown.replacingOccurrences(of: "![](", with: "![\u{200B}](")
        guard let document = try? AttributedString(markdown: source, options: options) else {
            return "<pre class=\"plain\">\(HTML.escape(markdown))</pre>"
        }

        var html = ""
        var openBlocks: [PresentationIntent.IntentType] = []  // outermost first

        for run in document.runs {
            // `components` is innermost-first; we want outermost-first to diff against the open stack.
            let chain = Array((run.presentationIntent?.components ?? []).reversed())

            var shared = 0
            while shared < openBlocks.count, shared < chain.count,
                  openBlocks[shared].identity == chain[shared].identity {
                shared += 1
            }
            for index in openBlocks.indices.reversed() where index >= shared {
                html += closingTag(for: openBlocks[index], ancestors: openBlocks[..<index])
            }
            openBlocks.removeSubrange(shared...)

            for index in chain.indices where index >= shared {
                html += openingTag(for: chain[index], ancestors: chain[..<index])
                openBlocks.append(chain[index])
            }

            // Foundation represents `---` with a placeholder glyph; the <hr> already says it all.
            if case .thematicBreak = chain.last?.kind { continue }

            let text = String(document[run.range].characters)
            let inCodeBlock = chain.contains { if case .codeBlock = $0.kind { true } else { false } }
            html += inlineHTML(text, run: run, inCodeBlock: inCodeBlock)
        }
        for index in openBlocks.indices.reversed() {
            html += closingTag(for: openBlocks[index], ancestors: openBlocks[..<index])
        }
        return renderTaskLists(in: html)
    }

    // MARK: - Blocks

    private static func openingTag(
        for intent: PresentationIntent.IntentType,
        ancestors: ArraySlice<PresentationIntent.IntentType>
    ) -> String {
        switch intent.kind {
        case .paragraph:
            return "<p>"
        case .header(let level):
            return "<h\(level)>"
        case .orderedList:
            return "<ol>"
        case .unorderedList:
            return "<ul>"
        case .listItem(let ordinal):
            if case .orderedList = ancestors.last?.kind { return "<li value=\"\(ordinal)\">" }
            return "<li>"
        case .codeBlock(let language):
            if let language, !language.isEmpty {
                return "<pre><code class=\"language-\(HTML.escape(language))\">"
            }
            return "<pre><code>"
        case .blockQuote:
            return "<blockquote>"
        case .thematicBreak:
            return "<hr>"
        case .table:
            return "<div class=\"table\"><table>"
        case .tableHeaderRow:
            return "<thead><tr>"
        case .tableRow:
            return "<tr>"
        case .tableCell(let column):
            let isHeader = ancestors.contains { if case .tableHeaderRow = $0.kind { true } else { false } }
            let tag = isHeader ? "th" : "td"
            return "<\(tag)\(alignmentAttribute(column: column, ancestors: ancestors))>"
        @unknown default:
            return "<div>"
        }
    }

    private static func closingTag(
        for intent: PresentationIntent.IntentType,
        ancestors: ArraySlice<PresentationIntent.IntentType>
    ) -> String {
        switch intent.kind {
        case .paragraph: return "</p>\n"
        case .header(let level): return "</h\(level)>\n"
        case .orderedList: return "</ol>\n"
        case .unorderedList: return "</ul>\n"
        case .listItem: return "</li>\n"
        case .codeBlock: return "</code></pre>\n"
        case .blockQuote: return "</blockquote>\n"
        case .thematicBreak: return "\n"
        case .table: return "</table></div>\n"
        case .tableHeaderRow: return "</tr></thead>\n"
        case .tableRow: return "</tr>\n"
        case .tableCell:
            let isHeader = ancestors.contains { if case .tableHeaderRow = $0.kind { true } else { false } }
            return isHeader ? "</th>" : "</td>"
        @unknown default: return "</div>"
        }
    }

    private static func alignmentAttribute(
        column: Int,
        ancestors: ArraySlice<PresentationIntent.IntentType>
    ) -> String {
        for ancestor in ancestors.reversed() {
            guard case .table(let columns) = ancestor.kind, columns.indices.contains(column) else { continue }
            switch columns[column].alignment {
            case .center: return " style=\"text-align:center\""
            case .right: return " style=\"text-align:right\""
            default: return ""
            }
        }
        return ""
    }

    // MARK: - Inlines

    private static func inlineHTML(_ text: String, run: AttributedString.Runs.Run, inCodeBlock: Bool) -> String {
        if inCodeBlock { return HTML.escape(text) }

        let intent = run.inlinePresentationIntent ?? []
        if intent.contains(.inlineHTML) || intent.contains(.blockHTML) { return text }
        if intent.contains(.lineBreak) { return "<br>\n" }
        if intent.contains(.softBreak) { return "\n" }

        if let image = run.imageURL {
            let alt = text.replacingOccurrences(of: "\u{200B}", with: "")
            return "<img src=\"\(HTML.escape(image.relativeString))\" alt=\"\(HTML.escape(alt))\">"
        }

        var html = HTML.escape(text)
        if intent.contains(.code) { html = "<code>\(html)</code>" }
        if intent.contains(.strikethrough) { html = "<del>\(html)</del>" }
        if intent.contains(.emphasized) { html = "<em>\(html)</em>" }
        if intent.contains(.stronglyEmphasized) { html = "<strong>\(html)</strong>" }
        if let link = run.link { html = "<a href=\"\(HTML.escape(link.relativeString))\">\(html)</a>" }
        return html
    }

    /// Foundation doesn't know GFM task lists, so `- [ ] item` arrives as literal text.
    private static func renderTaskLists(in html: String) -> String {
        guard let pattern = try? Regex(#"<li( value="\d+")?><p>\[([ xX])\] "#) else { return html }
        return html.replacing(pattern) { match in
            let value = match.output[1].substring.map(String.init) ?? ""
            let checked = match.output[2].substring == " " ? "" : " checked"
            return "<li class=\"task\"\(value)><p><input type=\"checkbox\" disabled\(checked)> "
        }
    }
}

nonisolated enum HTML {
    static func escape(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }
}
