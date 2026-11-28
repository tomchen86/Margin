import Foundation
import MarginReader
import SwiftUI
import Testing
import UIKit
import WebKit

/// docs/specs/markdown/spec.md, highlighted code, through the reader.
@MainActor
@Suite(.serialized)
struct HighlightingTests {
    @Test(
        "[MARKDOWN-21.1] colors the syntax of common languages, by name or alias, leaving the text as typed",
        arguments: [
            ("swift", "func greet() -> String {\n    return \"Hello <World>\"\n}", "func"),
            ("py", "def greet():\n    return 'hi'  # say hi", "def"),
            ("js", "function greet() { return 1 < 2; }", "function"),
            ("sh", "if [ -f notes.md ]; then echo found; fi", "if"),
            ("json", #"{"ripe": true, "count": 3}"#, "true"),
            ("yml", "fruit: lychee\nripe: true", "true"),
            ("sql", "SELECT name FROM fruit WHERE ripe = 1;", "SELECT"),
            ("diff", "- old line\n+ new line", "+ new line"),
        ])
    func colorsKnownLanguages(language: String, code: String, token: String) async throws {
        let shown = try await Self.show("```\(language)\n\(code)\n```\n")
        defer { shown.close() }
        let block = try await Self.colors(of: token, in: shown)
        #expect(block.text == code, "the code is as typed")
        #expect(block.token != nil && block.token != block.plain, "\(token) stands out: \(block)")
    }

    @Test(
        "[MARKDOWN-21.1] uses colors for light and dark mode, readable on the block's background",
        arguments: [UIUserInterfaceStyle.light, .dark])
    func followsTheMode(style: UIUserInterfaceStyle) async throws {
        let markdown = "```swift\nfunc greet() -> String { \"hi\" }\n```\n"
        let light = try await Self.show(markdown, style: .light)
        let lightColors = try await Self.colors(of: "func", in: light)
        light.close()
        let shown = try await Self.show(markdown, style: style)
        defer { shown.close() }
        let colors = try await Self.colors(of: "func", in: shown)
        #expect(colors.contrast >= 3, "func contrasts with the block's background: \(colors)")
        if style == .dark {
            #expect(colors.token != lightColors.token, "func changes color in dark mode: \(colors), \(lightColors)")
        }
    }

    @Test("[MARKDOWN-22.1] shows unnamed, unknown, and indented code in one color, without guessing")
    func doesNotGuess() async throws {
        let code = "func greet() {\n    return \"hi\"\n}"
        let indented = code.split(separator: "\n").map { "    " + $0 }.joined(separator: "\n")
        let markdown =
            "```swift\n\(code)\n```\n\n```\n\(code)\n```\n\n```fortran\n\(code)\n```\n\nIndented:\n\n\(indented)\n"
        let shown = try await Self.show(markdown)
        defer { shown.close() }
        let blocks = try await shown.json(
            [[String]].self,
            """
            return [...document.querySelectorAll("pre")].map(pre => {
              const colors = new Set();
              const walker = document.createTreeWalker(pre, NodeFilter.SHOW_TEXT);
              for (let node = walker.nextNode(); node; node = walker.nextNode()) {
                if (node.data.trim()) colors.add(getComputedStyle(node.parentElement).color);
              }
              return [pre.textContent.replace(/\\n$/, ""), String(colors.size), getComputedStyle(pre).fontFamily];
            });
            """)
        #expect(blocks.count == 4, "four code blocks")
        #expect(blocks.first?.dropFirst().first != "1", "the swift block is colored: \(blocks.first ?? [])")
        for block in blocks.dropFirst() {
            #expect(block.first == code, "as typed")
            #expect(block.dropFirst().first == "1", "one color: \(block)")
            #expect(block.last?.contains("monospace") == true, "monospaced: \(block)")
        }
    }

    // MARK: Fixtures

    /// The code block's text, and the colors of `token`, of its plain text, and of its background,
    /// with the contrast between `token` and the background.
    private struct Colors: Decodable, CustomStringConvertible {
        let text: String
        let token, plain: String?
        let contrast: Double

        var description: String { "token \(token ?? "none"), plain \(plain ?? "none"), contrast \(contrast)" }
    }

    private static func colors(of token: String, in shown: ShownDocument) async throws -> Colors {
        try await shown.json(
            Colors.self,
            """
            const pre = document.querySelector("pre");
            if (!pre) return { text: "", token: null, plain: null, contrast: 0 };
            const channels = color => (color.match(/[\\d.]+/g) ?? []).map(Number);
            const rgba = color => { const [r = 0, g = 0, b = 0, a = 1] = channels(color); return [r, g, b, a]; };
            const luminance = ([red, green, blue]) => {
              const [r, g, b] = [red, green, blue].map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
              return 0.2126 * r + 0.7152 * g + 0.0722 * b;
            };
            // The background as painted: every fill from <code> up to the first opaque one, or the
            // page's Canvas color, composited from the bottom up.
            const layers = [];
            for (let e = pre.querySelector("code") ?? pre; e; e = e.parentElement) {
              const color = rgba(getComputedStyle(e).backgroundColor);
              if (color[3] > 0) layers.push(color);
              if (color[3] >= 1) break;
            }
            if (!layers.length || layers[layers.length - 1][3] < 1) {
              const canvas = document.createElement("div");
              canvas.style.backgroundColor = "Canvas";
              document.documentElement.append(canvas);
              layers.push(rgba(getComputedStyle(canvas).backgroundColor));
              canvas.remove();
            }
            let background = layers[layers.length - 1].slice(0, 3);
            for (let i = layers.length - 2; i >= 0; i--) {
              const [r, g, b, a] = layers[i];
              background = [r * a + background[0] * (1 - a), g * a + background[1] * (1 - a), b * a + background[2] * (1 - a)];
            }
            let tokenColor = null;
            const walker = document.createTreeWalker(pre, NodeFilter.SHOW_TEXT);
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (node.data.trim() === token || node.data.trim().startsWith(token)) {
                tokenColor = getComputedStyle(node.parentElement).color; break;
              }
            }
            const plain = getComputedStyle(pre.querySelector("code") ?? pre).color;
            const [a, b] = [luminance(rgba(tokenColor ?? plain)), luminance(background)].sort((x, y) => y - x);
            return { text: pre.textContent.replace(/\\n$/, ""), token: tokenColor, plain,
                     contrast: (a + 0.05) / (b + 0.05) };
            """, ["token": token])
    }

    /// Shows `markdown` as `Code.md` in a phone-sized window in `style`.
    private static func show(_ markdown: String, style: UIUserInterfaceStyle = .light) async throws -> ShownDocument {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Code.md")
        try Data(markdown.utf8).write(to: file)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let reader = Reader(documentURL: file)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: ShownDocument.phone)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: WebView(reader.page).ignoresSafeArea())
        window.makeKeyAndVisible()
        try await reader.load()
        return ShownDocument(reader: reader, window: window)
    }
}
