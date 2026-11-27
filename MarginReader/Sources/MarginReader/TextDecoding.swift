import CoreFoundation
import Foundation

/// How a document's bytes become text (DOCUMENTS-8.1 to 11.1): a byte-order mark decides first,
/// then valid UTF-8, then Big5, GB18030, or Shift-JIS when one decodes the bytes without loss,
/// and otherwise UTF-8 with replacement marks.
enum TextDecoding {
    /// The legacy encodings tried after UTF-8, in the order used when the system's detector
    /// picks none of them.
    static let legacyEncodings: [String.Encoding] = [
        encoding(.big5), encoding(.GB_18030_2000), .shiftJIS,
    ]

    static func string(from data: Data) -> String {
        if let marked = decodingByteOrderMark(data) {
            return marked
        }
        if let utf8 = String(validating: data, as: UTF8.self) {
            return utf8
        }
        if let legacy = detectedLegacyEncoding(data) ?? firstLosslessLegacyEncoding(data) {
            return legacy
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// The text after a UTF-8, UTF-16, or UTF-32 byte-order mark, in that encoding and byte order,
    /// without the mark; nil when the data has no mark. Bytes the encoding can't read become
    /// replacement marks.
    static func decodingByteOrderMark(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(4))
        // The UTF-32 little-endian mark starts like the UTF-16 one, so it is checked first.
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return String(decoding: codeUnits(data.dropFirst(4), size: 4, bigEndian: false), as: UTF32.self)
        }
        if bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return String(decoding: codeUnits(data.dropFirst(4), size: 4, bigEndian: true), as: UTF32.self)
        }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }
        if bytes.starts(with: [0xFF, 0xFE]) {
            return String(decoding: codeUnits(data.dropFirst(2), size: 2, bigEndian: false), as: UTF16.self)
        }
        if bytes.starts(with: [0xFE, 0xFF]) {
            return String(decoding: codeUnits(data.dropFirst(2), size: 2, bigEndian: true), as: UTF16.self)
        }
        return nil
    }

    /// The text in the legacy encoding the system's detector picks, limited to the three; nil when
    /// it picks none or can't convert the bytes without loss.
    static func detectedLegacyEncoding(_ data: Data) -> String? {
        var converted: NSString?
        var lossy = ObjCBool(false)
        _ = NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .suggestedEncodingsKey: legacyEncodings.map { NSNumber(value: $0.rawValue) },
                .useOnlySuggestedEncodingsKey: true,
                .allowLossyKey: false,
            ],
            convertedString: &converted,
            usedLossyConversion: &lossy)
        // The detector can name an encoding without converting anything, so only a converted,
        // lossless string counts.
        guard let converted, !lossy.boolValue else { return nil }
        return converted as String
    }

    /// The text in the first of Big5, GB18030, and Shift-JIS that decodes the bytes without loss.
    static func firstLosslessLegacyEncoding(_ data: Data) -> String? {
        legacyEncodings.lazy.compactMap { String(data: data, encoding: $0) }.first
    }

    /// `bytes` as code units of `size` bytes, a trailing partial unit ending in a replacement mark.
    private static func codeUnits<Unit: FixedWidthInteger & UnsignedInteger>(
        _ bytes: Data, size: Int, bigEndian: Bool
    ) -> [Unit] {
        let bytes = [UInt8](bytes)
        var units: [Unit] = []
        units.reserveCapacity(bytes.count / size + 1)
        var index = 0
        while index + size <= bytes.count {
            var unit: Unit = 0
            for offset in 0..<size {
                let byte = Unit(bytes[index + (bigEndian ? offset : size - 1 - offset)])
                unit = unit << 8 | byte
            }
            units.append(unit)
            index += size
        }
        // A unit cut short can't be a scalar; this one decodes to a replacement mark.
        if index < bytes.count {
            units.append(size == 2 ? 0xDC00 : 0xFFFF_FFFF)
        }
        return units
    }

    private static func encoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
    }
}
