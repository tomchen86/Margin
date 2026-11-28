import Foundation
import Testing

@testable import MarginReader

/// What the reader's `margin://` handler answers, and what it can't serve.
@Suite struct ReaderSchemeTests {
    let document = URL(filePath: "/tmp/Folder with spaces/Notes 筆記.md")
    let grants = FolderGrants(defaultsKey: "ReaderSchemeTests.grants")

    @Test func pageURLRoundTripsPathsWithSpacesAndNonASCII() {
        let url = ReaderScheme.pageURL(for: document)
        #expect(url.scheme == "margin")
        #expect(url.host() == "file")
        #expect(ReaderScheme.isPage(url, of: document))
        #expect(!ReaderScheme.isPage(ReaderScheme.pageURL(for: URL(filePath: "/tmp/Other.md")), of: document))
    }

    @Test func servesTheBundledStylesheet() throws {
        let (data, mimeType) = try ReaderSchemeHandler.contents(
            of: ReaderScheme.appURL("text.css"), documentURL: document, grants: grants)
        #expect(mimeType == "text/css")
        #expect(String(decoding: data, as: UTF8.self).contains("pre.text"))
    }

    @Test(arguments: [
        "margin://app/", "margin://app/missing.css", "margin://app/Web/text.css", "margin://app/../Info.plist",
        "margin://app/%2E%2E/Info.plist", "margin://app/fonts/", "margin://app/fonts/../text.css",
        "margin://app/fonts/x/KaTeX_Main-Regular.woff2", "margin://file/tmp/Other.md", "margin://elsewhere/text.css",
    ])
    func refusesWhatItCannotServe(_ request: String) throws {
        let url = try #require(URL(string: request))
        #expect(throws: (any Error).self) {
            try ReaderSchemeHandler.contents(of: url, documentURL: document, grants: grants)
        }
    }

    @Test func servesKaTeXsFontsFromTheirFolder() throws {
        let (data, _) = try ReaderSchemeHandler.contents(
            of: ReaderScheme.appURL("fonts/KaTeX_Main-Regular.woff2"), documentURL: document, grants: grants)
        #expect(data.starts(with: Data("wOF2".utf8)))
    }

    @Test func servesAFileNextToTheDocumentAsItIs() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder.appending(path: "images"), withIntermediateDirectories: true)
        let image = folder.appending(path: "images/my photo.svg")
        try Data("<svg xmlns='http://www.w3.org/2000/svg'/>".utf8).write(to: image)
        let request = try #require(URL(string: ReaderScheme.fileURL + image.path(percentEncoded: true) + "?raw=true"))
        let (data, mimeType) = try ReaderSchemeHandler.contents(
            of: request, documentURL: folder.appending(path: "Notes.md"), grants: grants)
        #expect(data == (try Data(contentsOf: image)))
        #expect(mimeType == "image/svg+xml")
    }

    @Test func escapesEverythingHTMLWouldReadAsMarkup() {
        #expect(TextPage.escaped(#"<a href="x">&amp;</a>"#) == "&lt;a href=&quot;x&quot;&gt;&amp;amp;&lt;/a&gt;")
        #expect(TextPage.escaped("plain\ttext 筆記\n") == "plain\ttext 筆記\n")
    }
}
