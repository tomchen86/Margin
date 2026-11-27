import Foundation
import Testing

@testable import MarginReader

/// What the reader's `margin://` handler answers, and what it refuses.
@Suite struct ReaderSchemeTests {
    let document = URL(filePath: "/tmp/Folder with spaces/Notes 筆記.md")

    @Test func pageURLRoundTripsPathsWithSpacesAndNonASCII() {
        let url = ReaderScheme.pageURL(for: document)
        #expect(url.scheme == "margin")
        #expect(url.host() == "file")
        #expect(ReaderScheme.isPage(url, of: document))
        #expect(!ReaderScheme.isPage(ReaderScheme.pageURL(for: URL(filePath: "/tmp/Other.md")), of: document))
    }

    @Test func servesTheBundledStylesheet() throws {
        let (data, mimeType) = try ReaderSchemeHandler.contents(
            of: ReaderScheme.appURL("text.css"), documentURL: document)
        #expect(mimeType == "text/css")
        #expect(String(decoding: data, as: UTF8.self).contains("pre.text"))
    }

    @Test(arguments: [
        "margin://app/", "margin://app/missing.css", "margin://app/Web/text.css", "margin://app/../Info.plist",
        "margin://app/%2E%2E/Info.plist", "margin://file/tmp/Other.md", "margin://elsewhere/text.css",
    ])
    func refusesAnythingButTheDocumentAndBundledFiles(_ request: String) throws {
        let url = try #require(URL(string: request))
        #expect(throws: (any Error).self) { try ReaderSchemeHandler.contents(of: url, documentURL: document) }
    }

    @Test func escapesEverythingHTMLWouldReadAsMarkup() {
        #expect(TextPage.escaped(#"<a href="x">&amp;</a>"#) == "&lt;a href=&quot;x&quot;&gt;&amp;amp;&lt;/a&gt;")
        #expect(TextPage.escaped("plain\ttext 筆記\n") == "plain\ttext 筆記\n")
    }
}
