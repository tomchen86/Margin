import Foundation
import Testing

@testable import MarginReader

/// How the reader picks a document's page, and how a Markdown page carries its source.
@Suite struct MarkdownPageTests {
    @Test(arguments: ["a.md", "a.markdown", "a.mdown", "a.mkd", "a.mkdn", "README.MD", "Notes.Markdown"])
    func markdownExtensionsGetTheMarkdownPage(_ name: String) {
        #expect(DocumentKind(documentURL: URL(filePath: "/tmp/\(name)")) == .markdown)
    }

    @Test(arguments: ["a.txt", "a.html", "a.json", "a.md.txt", "md", "a.mdx"])
    func otherFilesGetTheTextPage(_ name: String) {
        #expect(DocumentKind(documentURL: URL(filePath: "/tmp/\(name)")) == .text)
    }

    @Test func sourceRoundTripsThroughJSON() throws {
        let source = "# T\n\"q\" \\ \t\r\u{1} \u{2028}\u{2029} 筆記 😀 </script><!--<script>"
        let json = MarkdownPage.jsonString(source)
        let decoded = try JSONDecoder().decode(String.self, from: Data(json.utf8))
        #expect(decoded == source)
    }

    @Test func sourceCannotEndOrReopenItsScriptElement() {
        let json = MarkdownPage.jsonString("</script><script>alert(1)</script><!--<script>")
        #expect(!json.contains("<"))
    }

    @Test func pageLoadsOnlyTheAppsScriptsAndStyles() {
        let page = MarkdownPage.html("# Title", title: "Notes.md")
        let sources = page.matches(of: /(?:src|href)="([^"]+)"/).map { String($0.output.1) }
        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { $0.hasPrefix("margin://app/") })
    }
}
