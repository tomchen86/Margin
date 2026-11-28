import CoreFoundation
import Foundation
import Testing

/// docs/specs/documents/spec.md, how a document's bytes become text, through the reader.
@MainActor
@Suite(.serialized)
struct EncodingsTests {
    @Test("[DOCUMENTS-8.1] decodes UTF-8 as UTF-8, though another encoding could decode it too")
    func decodesUTF8First() async throws {
        let text = "中文筆記 and café"
        let shown = try await ShownDocument.show(Data(text.utf8), named: "UTF-8.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test(
        "[DOCUMENTS-9.1] decodes old notes in Big5, GB18030, and Shift-JIS",
        arguments: [
            ("舊筆記：今天天氣很好，我們去公園散步。這是繁體中文的檔案。", Self.big5),
            ("旧笔记：今天天气很好，我们去公园散步。这是简体中文的文件。", Self.gb18030),
            ("古いメモ：今日はいい天気です。公園を散歩しました。日本語のファイルです。", String.Encoding.shiftJIS),
        ])
    func decodesOldNotes(text: String, encoding: String.Encoding) async throws {
        let shown = try await ShownDocument.show(try Self.bytes(text, encoding), named: "Old notes.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test(
        "[DOCUMENTS-9.1] decodes a few characters as the encoding they were written in",
        arguments: [("天氣", Self.big5), ("中文", Self.gb18030)])
    func decodesAFewCharacters(text: String, encoding: String.Encoding) async throws {
        let shown = try await ShownDocument.show(try Self.bytes(text, encoding), named: "Short.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test("[DOCUMENTS-9.1] decodes a Markdown note in Big5")
    func decodesMarkdownInBig5() async throws {
        let shown = try await ShownDocument.show(
            try Self.bytes("# 舊筆記\n\n今天天氣很好，我們去公園散步。\n", Self.big5), named: "筆記.md")
        defer { shown.close() }
        let text = try await shown.visibleText()
        #expect(text.contains("舊筆記"))
        #expect(text.contains("今天天氣很好，我們去公園散步。"))
    }

    @Test(
        "[DOCUMENTS-10.1] decodes after a byte-order mark and hides the mark",
        arguments: ["UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE"])
    func decodesAfterAByteOrderMark(form: String) async throws {
        let text = "中文 notes"
        let marked: Data
        switch form {
        case "UTF-8": marked = Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
        case "UTF-16LE": marked = Data([0xFF, 0xFE]) + (try Self.bytes(text, .utf16LittleEndian))
        case "UTF-16BE": marked = Data([0xFE, 0xFF]) + (try Self.bytes(text, .utf16BigEndian))
        case "UTF-32LE": marked = Data([0xFF, 0xFE, 0x00, 0x00]) + (try Self.bytes(text, .utf32LittleEndian))
        default: marked = Data([0x00, 0x00, 0xFE, 0xFF]) + (try Self.bytes(text, .utf32BigEndian))
        }
        let shown = try await ShownDocument.show(marked, named: "Marked.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == text)
    }

    @Test("[DOCUMENTS-11.1] shows what fits no encoding as UTF-8 with replacement marks")
    func replacesWhatFitsNothing() async throws {
        let shown = try await ShownDocument.show(
            try Self.bytes("Café au lait", .windowsCP1252), named: "Windows.txt")
        defer { shown.close() }
        #expect(try await shown.visibleText() == "Caf\u{FFFD} au lait")
    }

    nonisolated private static let big5 = encoding(.big5)
    nonisolated private static let gb18030 = encoding(.GB_18030_2000)

    nonisolated private static func encoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
    }

    private static func bytes(_ text: String, _ encoding: String.Encoding) throws -> Data {
        try #require(text.data(using: encoding, allowLossyConversion: false), "\(text) fits \(encoding)")
    }
}
