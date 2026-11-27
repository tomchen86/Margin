import Foundation
import MarginReader
import SwiftUI
import Testing
import UIKit
import WebKit

/// A document shown the way the app shows it: a `Reader` whose page sits in a `WebView`, in a
/// window of a known size, so the page lays out as it would on screen.
@MainActor
struct ShownDocument {
    /// iPhone 17 Pro in portrait.
    static let phone = CGSize(width: 402, height: 874)

    let reader: Reader
    let window: UIWindow

    /// Writes `contents` to a file called `name` in a new folder of its own, then shows it.
    static func show(_ contents: Data, named name: String, in size: CGSize = phone) async throws -> ShownDocument {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: name)
        try contents.write(to: file)
        return try await show(file, in: size)
    }

    static func show(_ text: String, named name: String, in size: CGSize = phone) async throws -> ShownDocument {
        try await show(Data(text.utf8), named: name, in: size)
    }

    static func show(_ file: URL, in size: CGSize = phone) async throws -> ShownDocument {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let reader = Reader(documentURL: file)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: WebView(reader.page).ignoresSafeArea())
        window.makeKeyAndVisible()
        try await reader.load()
        return ShownDocument(reader: reader, window: window)
    }

    /// Runs `body` as a JavaScript function in the page; `arguments` become its local variables.
    func evaluate(_ body: String, _ arguments: [String: Any] = [:]) async throws -> Any? {
        try await reader.page.callJavaScript(body, arguments: arguments)
    }

    /// The text the page shows, as the owner would select and copy it.
    func visibleText() async throws -> String {
        try #require(try await evaluate("return document.body ? document.body.innerText : ''") as? String)
    }

    /// The on-screen boxes of the first occurrence of `text` inside one text node, one box per line
    /// it takes up; empty when the page does not show `text`.
    func lineBoxes(of text: String) async throws -> [CGRect] {
        let script = """
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              const start = node.data.indexOf(text);
              if (start < 0) continue;
              const range = document.createRange();
              range.setStart(node, start);
              range.setEnd(node, start + text.length);
              return [...range.getClientRects()].filter(r => r.width > 0)
                .map(r => [r.left, r.top, r.width, r.height]);
            }
            return [];
            """
        let boxes = try #require(try await evaluate(script, ["text": text]) as? [[Double]])
        return boxes.map { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
    }

    /// The computed style `property` of the element that holds the first occurrence of `text`.
    func style(_ property: String, of text: String) async throws -> String? {
        let script = """
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (node.data.includes(text)) return getComputedStyle(node.parentElement).getPropertyValue(property);
            }
            return null;
            """
        return try await evaluate(script, ["text": text, "property": property]) as? String
    }

    /// The pieces of text the page shows in bold or italic.
    func boldOrItalicText() async throws -> [String] {
        let script = """
            const styled = [];
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (!node.data.trim()) continue;
              const style = getComputedStyle(node.parentElement);
              if (Number(style.fontWeight) >= 600 || style.fontStyle !== "normal") styled.push(node.data);
            }
            return styled;
            """
        return try #require(try await evaluate(script) as? [String])
    }

    func close() {
        window.isHidden = true
    }
}
