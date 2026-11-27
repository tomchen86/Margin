import Foundation

/// Decodes text files that aren't always UTF-8 (old Big5 / GB18030 / Shift-JIS files are common).
nonisolated enum TextDecoding {
    static func string(from data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.hasPrefix("\u{FEFF}") ? String(utf8.dropFirst()) : utf8
        }

        var converted: NSString?
        var usedLossy: ObjCBool = false
        let detected = NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .suggestedEncodingsKey: [big5.rawValue, gb18030.rawValue, String.Encoding.shiftJIS.rawValue],
                .allowLossyKey: false,
            ],
            convertedString: &converted,
            usedLossyConversion: &usedLossy
        )
        if detected != 0, let converted {
            return converted as String
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static let big5 = encoding(.big5)
    private static let gb18030 = encoding(.GB_18030_2000)

    private static func encoding(_ cf: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cf.rawValue)))
    }
}
