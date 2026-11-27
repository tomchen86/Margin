import Foundation
import MarginReader
import Testing
import UIKit

/// docs/specs/reading/spec.md, the source view, through the reader.
@MainActor
@Suite(.serialized)
struct SourceTests {
    @Test(
        "[READING-6.1] shows the source as written, monospaced, wrapped, at the body size",
        arguments: ["Notes.md", "Page.html"])
    func showsTheSource(name: String) async throws {
        let word = String(repeating: "w", count: 200)
        let text =
            name.hasSuffix(".md")
            ? "# Title\n\n  Some **bold** and <b>tags</b>.\n\n\(word)"
            : "<!doctype html>\n<p>Kumquat &amp; <b>pear</b></p>\n<script>document.body.append(\"Pom\" + \"elo\")</script>\n\(word)"
        let shown = try await ShownDocument.show(text, named: name)
        defer { shown.close() }
        try await shown.reader.load(showingSource: true)
        #expect(try await shown.visibleText() == text, "the file's text as written")
        let marker = name.hasSuffix(".md") ? "Title" : "Kumquat"
        let family = try #require(try await shown.style("font-family", of: marker))
        #expect(family.hasPrefix("ui-monospace"), "the system's monospaced font: \(family)")
        let body = UIFont.preferredFont(forTextStyle: .body).pointSize
        let size = try await shown.style("font-size", of: word)
        #expect(size == "\(Int(body))px", "the body size, \(body): \(String(describing: size))")
        let page = try #require(
            try await shown.evaluate("return [innerWidth, document.documentElement.scrollWidth]") as? [Int])
        #expect(page[1] <= page[0], "long lines wrap; the page does not scroll sideways")
    }
}
