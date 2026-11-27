import Foundation
import Testing

@testable import MarginReader

/// The parts of decoding that documents alone can't reach.
@Suite struct TextDecodingTests {
    @Test func fallbackTriesBig5ThenGB18030ThenShiftJIS() throws {
        // `中文` in GB18030 also decodes without loss as Big5, so Big5 comes first.
        let bytes = try #require("中文".data(using: TextDecoding.legacyEncodings[1]))
        let big5 = try #require(String(data: bytes, encoding: TextDecoding.legacyEncodings[0]))
        #expect(TextDecoding.firstLosslessLegacyEncoding(bytes) == big5)
    }

    @Test func detectorCountsOnlyAConvertedString() throws {
        let windows1252 = try #require("Café au lait".data(using: .windowsCP1252))
        #expect(TextDecoding.detectedLegacyEncoding(windows1252) == nil)
        #expect(TextDecoding.firstLosslessLegacyEncoding(windows1252) == nil)
        #expect(TextDecoding.string(from: windows1252) == "Caf\u{FFFD} au lait")
    }

    @Test func noMarkMeansNoMarkedDecoding() {
        #expect(TextDecoding.decodingByteOrderMark(Data("plain".utf8)) == nil)
        #expect(TextDecoding.decodingByteOrderMark(Data()) == nil)
        #expect(TextDecoding.string(from: Data()) == "")
    }

    @Test func utf32LittleEndianMarkWinsOverUTF16() {
        let data = Data([0xFF, 0xFE, 0x00, 0x00, 0x41, 0x00, 0x00, 0x00])
        #expect(TextDecoding.decodingByteOrderMark(data) == "A")
    }

    @Test func aCutShortUnitBecomesAReplacementMark() {
        #expect(TextDecoding.decodingByteOrderMark(Data([0xFF, 0xFE, 0x41, 0x00, 0x42])) == "A\u{FFFD}")
        #expect(TextDecoding.decodingByteOrderMark(Data([0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00])) == "\u{FFFD}")
        #expect(TextDecoding.decodingByteOrderMark(Data([0xEF, 0xBB, 0xBF, 0xFF])) == "\u{FFFD}")
    }

    @Test func aMarkAloneIsAnEmptyText() {
        #expect(TextDecoding.decodingByteOrderMark(Data([0xFE, 0xFF])) == "")
        #expect(TextDecoding.decodingByteOrderMark(Data([0xEF, 0xBB, 0xBF])) == "")
    }
}
