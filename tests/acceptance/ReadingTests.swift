import Foundation
import MarginReader
import SwiftUI
import Testing
import UIKit
import WebKit

/// docs/specs/reading/spec.md, through the reader: a `Reader` showing a file in a window.
@MainActor
@Suite(.serialized)
struct ReadingTests {
    @Test("[READING-1.1] shows a Markdown document's headings, paragraphs, and lists in the system font")
    func usesTheSystemFont() async throws {
        let shown = try await Self.show("# Heading\n\nA paragraph.\n\n- An item\n", named: "Font.md")
        defer { shown.close() }
        let families = try await Self.json(
            [String].self,
            """
            return ["h1", "p", "li"].map(selector => {
              const element = document.querySelector(selector);
              return element ? getComputedStyle(element).fontFamily : "missing";
            });
            """, in: shown)
        let system = ["system-ui", "-apple-system", "-apple-system-body"]
        for family in families {
            let first = family.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            #expect(system.contains(first), "the system font comes first: \(families)")
        }
    }

    @Test(
        "[READING-2.1] sizes Markdown and plain text at the system's body size",
        arguments: [("Size.md", "Lychee orchard"), ("Size.txt", "Lychee orchard")])
    func usesTheBodySize(name: String, text: String) async throws {
        let shown = try await Self.show(name.hasSuffix(".md") ? "# Title\n\n\(text)\n" : text, named: name)
        defer { shown.close() }
        let body = UIFont.preferredFont(forTextStyle: .body).pointSize
        let size = try await shown.style("font-size", of: text)
        #expect(size == "\(Int(body))px", "the system's body size, \(body): \(String(describing: size))")
    }

    @Test(
        "[READING-4.1] shows dark text on light in light mode and light text on dark in dark mode",
        arguments: [
            ("Colors.md", UIUserInterfaceStyle.light), ("Colors.md", .dark), ("Colors.txt", .light),
            ("Colors.txt", .dark),
        ])
    func followsTheMode(name: String, style: UIUserInterfaceStyle) async throws {
        let shown = try await Self.show("Lychee orchard", named: name, style: style)
        defer { shown.close() }
        let colors = try await Self.colors(of: "Lychee orchard", in: shown)
        #expect(colors.dark == (style == .dark), "the page is in the window's mode")
        if style == .dark {
            #expect(colors.background < 0.2 && colors.text > 0.7, "light text on a dark background: \(colors)")
        } else {
            #expect(colors.background > 0.8 && colors.text < 0.3, "dark text on a light background: \(colors)")
        }
    }

    @Test("[READING-4.1] turns dark at once when the mode changes while a document is shown")
    func switchesWhileOpen() async throws {
        let shown = try await Self.show("# Title\n\nLychee orchard\n", named: "Switch.md", style: .light)
        defer { shown.close() }
        let light = try await Self.colors(of: "Lychee orchard", in: shown)
        #expect(light.background > 0.8, "light at first: \(light)")
        shown.window.overrideUserInterfaceStyle = .dark
        _ = try await shown.evaluate("await new Promise(resolve => setTimeout(resolve, 500)); return true")
        let dark = try await Self.colors(of: "Lychee orchard", in: shown)
        #expect(dark.dark && dark.background < 0.2 && dark.text > 0.7, "dark without reopening: \(dark)")
    }

    // MARK: Fixtures

    /// The page's mode, and the luminance (0 black to 1 white) of its background and of `text`.
    private struct Colors: Decodable, CustomStringConvertible {
        let dark: Bool
        let background, text: Double

        var description: String { "dark \(dark), background \(background), text \(text)" }
    }

    private static func colors(of text: String, in shown: ShownDocument) async throws -> Colors {
        try await json(
            Colors.self,
            """
            const luminance = color => {
              const [r, g, b, a = 1] = (color.match(/[\\d.]+/g) ?? []).map(Number);
              return a === 0 || r === undefined ? null : (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
            };
            const background = () => {
              for (const element of [document.body, document.documentElement]) {
                const value = element && luminance(getComputedStyle(element).backgroundColor);
                if (value !== null && value !== undefined) return value;
              }
              const canvas = document.createElement("div");
              canvas.style.backgroundColor = "Canvas";
              document.documentElement.append(canvas);
              const value = luminance(getComputedStyle(canvas).backgroundColor);
              canvas.remove();
              return value;
            };
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let holder = null;
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (node.data.includes(text)) { holder = node.parentElement; break; }
            }
            return { dark: matchMedia("(prefers-color-scheme: dark)").matches,
                     background: background() ?? -1,
                     text: holder ? luminance(getComputedStyle(holder).color) : -1 };
            """, ["text": text], in: shown)
    }

    /// Writes `contents` to a file called `name` and shows it in a phone-sized window in `style`.
    private static func show(_ contents: String, named name: String, style: UIUserInterfaceStyle = .light)
        async throws -> ShownDocument
    {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: name)
        try Data(contents.utf8).write(to: file)
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

    private static func json<Value: Decodable>(
        _ type: Value.Type, _ body: String, _ arguments: [String: Any] = [:], in shown: ShownDocument
    ) async throws -> Value {
        let value = try await shown.evaluate("return JSON.stringify(await (async () => { \(body) })());", arguments)
        let text = try #require(value as? String)
        return try JSONDecoder().decode(Value.self, from: Data(text.utf8))
    }
}
