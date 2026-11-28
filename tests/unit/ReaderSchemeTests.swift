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
        let resource = try ReaderSchemeHandler.contents(
            of: ReaderScheme.appURL("text.css"), documentURL: document, grants: grants)
        #expect(resource.mimeType == "text/css")
        #expect(resource.textEncoding == "utf-8")
        #expect(String(decoding: resource.data, as: UTF8.self).contains("pre.text"))
    }

    @Test(arguments: [
        "margin://app/", "margin://app/missing.css", "margin://app/Web/text.css", "margin://app/../Info.plist",
        "margin://app/%2E%2E/Info.plist", "margin://file/tmp/Other.md", "margin://elsewhere/text.css",
    ])
    func refusesWhatItCannotServe(_ request: String) throws {
        let url = try #require(URL(string: request))
        #expect(throws: (any Error).self) {
            try ReaderSchemeHandler.contents(of: url, documentURL: document, grants: grants)
        }
    }

    @Test func servesAFileNextToTheDocumentAsItIs() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder.appending(path: "images"), withIntermediateDirectories: true)
        let image = folder.appending(path: "images/my photo.svg")
        try Data("<svg xmlns='http://www.w3.org/2000/svg'/>".utf8).write(to: image)
        let request = try #require(URL(string: ReaderScheme.fileURL + image.path(percentEncoded: true) + "?raw=true"))
        let resource = try ReaderSchemeHandler.contents(
            of: request, documentURL: folder.appending(path: "Notes.md"), grants: grants)
        #expect(resource.data == (try Data(contentsOf: image)))
        #expect(resource.mimeType == "image/svg+xml")
        #expect(resource.textEncoding == nil, "WebKit finds a file's encoding itself")
    }

    @Test func escapesEverythingHTMLWouldReadAsMarkup() {
        #expect(TextPage.escaped(#"<a href="x">&amp;</a>"#) == "&lt;a href=&quot;x&quot;&gt;&amp;amp;&lt;/a&gt;")
        #expect(TextPage.escaped("plain\ttext 筆記\n") == "plain\ttext 筆記\n")
    }
}
