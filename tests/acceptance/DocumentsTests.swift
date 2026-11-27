import Foundation
import MarginReader
import Testing
import UIKit
import WebKit

/// docs/specs/documents/spec.md, through the reader: a `Reader` showing a file in a window.
@MainActor
@Suite(.serialized)
struct DocumentsTests {
    @Test("[DOCUMENTS-3.1] tells iOS it views every kind of document, in place")
    func opensInPlace() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["LSSupportsOpeningDocumentsInPlace"] as? Bool == true)
        let declared = try #require(info["CFBundleDocumentTypes"] as? [[String: Any]])
        let types = [
            "net.daringfireball.markdown", "public.html", "public.json", "public.yaml", "public.xml",
            "public.plain-text",
        ]
        for type in types {
            let entry = declared.first { ($0["LSItemContentTypes"] as? [String])?.contains(type) == true }
            #expect(entry?["CFBundleTypeRole"] as? String == "Viewer", "\(type) is declared with the Viewer role")
        }
    }

    @Test("[DOCUMENTS-6.1] keeps every space, tab, and blank line, including a blank first line")
    func keepsWhitespace() async throws {
        let text = "\nfirst line after a blank line\na   b\n\n\n    indented by four\n\tafter a tab\nlast line"
        let shown = try await ShownDocument.show(text, named: "Spacing.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test("[DOCUMENTS-6.1] shows markup as typed")
    func showsMarkupAsTyped() async throws {
        let text = "<b>bold</b> &amp; **stars** <i>not italic</i>\n<p>no paragraph</p> <!-- no comment -->"
        let shown = try await ShownDocument.show(text, named: "Markup.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
        #expect(try await shown.boldOrItalicText() == [], "nothing is bold or italic")
    }

    @Test("[DOCUMENTS-6.1] shows Markdown as typed")
    func showsMarkdownAsTyped() async throws {
        let text = "# Title\n\n*stars* and __underscores__ and `code`\n\n- [ ] task\n> quote"
        let shown = try await ShownDocument.show(text, named: "Notes.md")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
        #expect(try await shown.boldOrItalicText() == [], "nothing is bold or italic")
    }

    @Test("[DOCUMENTS-6.1] shows HTML as typed, without running its script")
    func showsHTMLAsTyped() async throws {
        let text = """
            <!doctype html>
            <h1>Title</h1>
            <p><b>bold</b> <i>italic</i></p>
            <script>document.body.textContent = "the script ran"</script>
            """
        let shown = try await ShownDocument.show(text, named: "Page.html")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
        #expect(try await shown.boldOrItalicText() == [], "nothing is bold or italic")
    }

    @Test(
        "[DOCUMENTS-6.1] shows JSON, YAML, and XML as typed",
        arguments: [
            "Data.json": "{\n  \"fruit\": \"Nectarine\",\n  \"count\": 3\n}",
            "Config.yaml": "fruit: Orange\nlist:\n  - one\n  - two",
            "Feed.xml":
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<feed>\n  <entry id=\"1\">Quince &amp; pear</entry>\n</feed>",
        ])
    func showsDataAsTyped(name: String, text: String) async throws {
        let shown = try await ShownDocument.show(text, named: name)
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test("[DOCUMENTS-6.1] shows source code as typed")
    func showsSourceCodeAsTyped() async throws {
        let text = "func first<T: Equatable>(_ items: [T]) -> T? {\n    items.first // a && b < c\n}"
        let shown = try await ShownDocument.show(text, named: "Generic.swift")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test("[DOCUMENTS-6.1] uses the system's monospaced font")
    func usesMonospacedFont() async throws {
        let shown = try await ShownDocument.show("iiiiiiiiii\nMMMMMMMMMM", named: "Widths.txt")
        defer { shown.close() }
        let narrow = try #require(try await shown.lineBoxes(of: "iiiiiiiiii").first)
        let wide = try #require(try await shown.lineBoxes(of: "MMMMMMMMMM").first)
        #expect(narrow.width > 0)
        #expect(abs(narrow.width - wide.width) < 0.5, "ten i are as wide as ten M")
        let family = try #require(try await shown.style("font-family", of: "MMMMMMMMMM"))
        #expect(family.hasPrefix("ui-monospace"), "the system's monospaced font comes first: \(family)")
    }

    @Test("[DOCUMENTS-6.1] wraps long lines and long words within the page")
    func wrapsLongLines() async throws {
        let word = String(repeating: "w", count: 200)
        let line = (0..<20).map { "word\($0)" }.joined(separator: " ") + " " + word + " tail"
        let shown = try await ShownDocument.show("short line\n" + line, named: "Long.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == "short line\n" + line)
        let boxes = try await shown.lineBoxes(of: word)
        #expect(boxes.count > 1, "the 200-character word wraps")
        let page = try #require(
            try await shown.evaluate("return [innerWidth, document.documentElement.scrollWidth]") as? [Int])
        #expect(page[1] <= page[0], "the page does not scroll sideways")
        for box in try await shown.lineBoxes(of: line) {
            #expect(box.minX >= 0 && box.maxX <= Double(page[0]), "every line fits the page")
        }
    }

    @Test(
        "[DOCUMENTS-7.1] wraps at 80 characters in a centered column on a wide page", arguments: ["txt", "md", "html"])
    func wrapsAtEightyCharacters(fileExtension: String) async throws {
        let line = String(repeating: "x", count: 200)
        let iPad = CGSize(width: 1194, height: 834)
        let shown = try await ShownDocument.show("0123456789\n" + line, named: "Wide." + fileExtension, in: iPad)
        defer { shown.close() }
        let ten = try #require(try await shown.lineBoxes(of: "0123456789").first)
        let first = try #require(try await shown.lineBoxes(of: line).first)
        #expect(abs(first.width / (ten.width / 10) - 80) < 0.5, "the first line holds 80 characters")
        let page = try #require(try await shown.evaluate("return innerWidth") as? Double)
        #expect(abs(page - iPad.width) < 1, "the page is as wide as the window")
        #expect(abs(first.minX - (page - first.maxX)) <= 1, "the column is centered")
    }

    @Test(
        "[DOCUMENTS-7.1] wraps at the right margin of a phone's page, before 80 characters",
        arguments: ["txt", "md", "html"])
    func wrapsAtPhoneMargin(fileExtension: String) async throws {
        let line = String(repeating: "x", count: 200)
        let shown = try await ShownDocument.show("0123456789\n" + line, named: "Narrow." + fileExtension)
        defer { shown.close() }
        let ten = try #require(try await shown.lineBoxes(of: "0123456789").first)
        let character = ten.width / 10
        let boxes = try await shown.lineBoxes(of: line)
        let first = try #require(boxes.first)
        #expect(first.width / character < 80)
        #expect(boxes.count >= 3, "200 characters take three lines or more")
        let page = try #require(try await shown.evaluate("return innerWidth") as? Double)
        #expect(boxes.allSatisfy { $0.minX >= 0 && $0.maxX <= page })
        #expect(first.minX <= 24, "the left margin is at most 24 points")
        #expect(
            page - first.maxX <= 24 + character,
            "the line wraps within one character of a right margin of at most 24 points")
    }

    @Test("[DOCUMENTS-6.1] shows an empty file as an empty page")
    func showsEmptyFile() async throws {
        let shown = try await ShownDocument.show(Data(), named: "Empty.txt")
        defer { shown.close() }
        #expect(shown.reader.page.url != nil, "the reader shows a page for the file")
        #expect(try await shown.visibleText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
