import Foundation
import Testing

@testable import MarginReader

/// How an HTML document is served: which documents count as declaring a charset, and where the
/// viewport tag goes when a document has none.
@Suite struct HTMLPageTests {
    @Test(arguments: [
        #"<!doctype html><meta charset="windows-1252">"#,
        #"<META CHARSET=shift_jis>"#,
        #"<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">"#,
        #"<meta content='text/html; charset=utf-8' http-equiv='content-type'>"#,
    ])
    func findsADeclaredCharset(_ head: String) {
        #expect(HTMLPage.declaresCharset(Data(head.utf8)))
    }

    @Test(arguments: [
        "<!doctype html><p>No declaration</p>",
        #"<meta name="description" content="Notes">"#,
        #"<meta http-equiv="refresh" content="5">"#,
        String(repeating: " ", count: 1024) + #"<meta charset="windows-1252">"#,
        #"<!-- <meta charset="windows-1252"> --><p>Text</p>"#,
        #"<!-- unclosed <meta charset="windows-1252">"#,
    ])
    func findsNoDeclaration(_ head: String) {
        #expect(!HTMLPage.declaresCharset(Data(head.utf8)))
    }

    @Test func servesADeclaredDocumentAsItIs() throws {
        let document = try #require(#"<meta charset="windows-1252"><p>Café</p>"#.data(using: .windowsCP1252))
        let (page, encoding) = HTMLPage.page(document)
        #expect(encoding == nil)
        #expect(page.suffix(document.count) == document, "the document's bytes are unchanged")
    }

    @Test func decodesAnUndeclaredDocumentAndServesItAsUTF8() throws {
        let big5 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        let document = try #require("<p>今天天氣很好，我們去公園散步。</p>".data(using: big5))
        let (page, encoding) = HTMLPage.page(document)
        #expect(encoding == "utf-8")
        #expect(String(decoding: page, as: UTF8.self).hasSuffix("<p>今天天氣很好，我們去公園散步。</p>"))
    }

    @Test func aByteOrderMarkOutranksADeclaration() {
        let document = Data([0xEF, 0xBB, 0xBF]) + Data(#"<meta charset="windows-1252"><p>Café</p>"#.utf8)
        let (page, encoding) = HTMLPage.page(document)
        #expect(encoding == "utf-8")
        #expect(String(decoding: page, as: UTF8.self).hasSuffix("<p>Café</p>"))
    }

    @Test func putsTheViewportTagAfterTheDoctype() {
        let page = HTMLPage.withViewport(Data("<!-- note -->\n<!DOCTYPE html>\n<p>Text</p>".utf8))
        #expect(
            String(decoding: page, as: UTF8.self)
                == "<!-- note -->\n<!DOCTYPE html>\(HTMLPage.viewport)\n<p>Text</p>")
    }

    @Test func putsTheViewportTagFirstWithoutADoctype() {
        let page = HTMLPage.withViewport(Data("<p>Text</p>".utf8))
        #expect(String(decoding: page, as: UTF8.self) == HTMLPage.viewport + "<p>Text</p>")
    }

    @Test func keepsTheDocumentsOwnViewportTag() {
        let document = Data(#"<!doctype html><meta name="viewport" content="width=600"><p>Text</p>"#.utf8)
        #expect(HTMLPage.withViewport(document) == document)
    }
}
