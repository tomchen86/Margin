import Foundation
import MarginReader
import SwiftUI
import Testing
import UIKit
import WebKit

/// docs/specs/html/spec.md, through the reader: a `Reader` showing an HTML file in a window.
@MainActor
@Suite(.serialized)
struct HTMLTests {
    // MARK: As written

    @Test("[HTML-1.1] applies the document's inline style and runs its inline script")
    func runsInlineStylesAndScripts() async throws {
        let html = """
            <!doctype html>
            <html><head><style>p.note { color: rgb(0, 128, 0); }</style></head>
            <body><p class="note">Green note</p>
            <script>
              const added = document.createElement("p");
              added.id = "added";
              added.textContent = "Added by the script";
              document.body.append(added);
            </script></body></html>
            """
        let shown = try await ShownDocument.show(html, named: "Inline.html")
        defer { shown.close() }
        struct Page: Decodable {
            let note, added: String?
        }
        let page = try await shown.json(
            Page.self,
            """
            const note = document.querySelector("p.note");
            return { note: note ? getComputedStyle(note).color : null,
                     added: document.getElementById("added")?.textContent ?? null };
            """)
        #expect(page.note == "rgb(0, 128, 0)", "the document's <style> applies")
        #expect(page.added == "Added by the script", "the document's script runs")
    }

    @Test("[HTML-1.1] uses the stylesheet, script, image, and data next to the document")
    func usesFilesNextToTheDocument() async throws {
        let html = """
            <!doctype html>
            <html><head><link rel="stylesheet" href="style.css"></head>
            <body><p class="styled">Blue text</p><p id="ran"></p><p id="data"></p>
            <img id="photo" src="images/photo.png" alt="photo">
            <script src="app.js"></script></body></html>
            """
        let script = """
            document.getElementById("ran").textContent = "app.js ran";
            fetch("data.json").then(response => response.json())
              .then(data => { document.getElementById("data").textContent = data.fruit; });
            """
        let shown = try await ShownDocument.show(
            files: [
                "Page.html": Data(html.utf8),
                "style.css": Data("p.styled { color: rgb(0, 0, 255); }".utf8),
                "app.js": Data(script.utf8),
                "data.json": Data(#"{"fruit": "Kumquat"}"#.utf8),
                "images/photo.png": Self.png(width: 120, height: 60),
            ],
            opening: "Page.html")
        defer { shown.close() }
        try await shown.settle(1)
        struct Page: Decodable {
            let styled, ran, data: String?
            let photo: Int
        }
        let page = try await shown.json(
            Page.self,
            """
            const styled = document.querySelector("p.styled");
            const photo = document.getElementById("photo");
            return { styled: styled ? getComputedStyle(styled).color : null,
                     ran: document.getElementById("ran")?.textContent ?? null,
                     data: document.getElementById("data")?.textContent ?? null,
                     photo: photo && photo.complete ? photo.naturalWidth : 0 };
            """)
        #expect(page.styled == "rgb(0, 0, 255)", "style.css applies")
        #expect(page.ran == "app.js ran", "app.js runs")
        #expect(page.data == "Kumquat", "the script reads data.json")
        #expect(page.photo == 120, "the image shows")
    }

    @Test("[HTML-1.1] adds no stylesheet or script of the reader's own")
    func addsNothingOfItsOwn() async throws {
        let shown = try await ShownDocument.show("<!doctype html><p>Plain paragraph</p>", named: "Plain.html")
        defer { shown.close() }
        struct Page: Decodable {
            let paragraph: String?
            let readerFiles, styles: Int
        }
        let page = try await shown.json(
            Page.self,
            """
            return { paragraph: document.querySelector("p")?.textContent ?? null,
                     readerFiles: document.querySelectorAll('link[href^="margin://app"], script[src^="margin://app"]').length,
                     styles: document.querySelectorAll("style, link[rel~=stylesheet]").length };
            """)
        #expect(page.paragraph == "Plain paragraph", "the reader renders the HTML")
        #expect(page.readerFiles == 0, "no file from the app")
        #expect(page.styles == 0, "no styles the document does not have")
    }

    @Test("[HTML-1.1] lets web scripts, stylesheets, images, and frames load, as a browser would")
    func letsWebContentLoad() async throws {
        let shown = try await ShownDocument.show("<!doctype html><p>Web page</p>", named: "Web.html")
        defer { shown.close() }
        let paragraph = try await shown.evaluate("return document.querySelector('p')?.textContent ?? null")
        #expect(paragraph as? String == "Web page", "the reader renders the HTML")
        #expect(try await !shown.policyRefuses("script", ["src": "https://margin.invalid/library.js"]))
        #expect(try await !shown.policyRefuses("link", ["rel": "stylesheet", "href": "https://margin.invalid/a.css"]))
        #expect(try await !shown.policyRefuses("img", ["src": "http://margin.invalid/a.png"]))
        #expect(try await !shown.policyRefuses("iframe", ["src": "https://margin.invalid/embed"]))
        #expect(try await !shown.policyRefuses("iframe", ["src": "http://margin.invalid/embed"]))
    }

    // MARK: Width

    @Test("[HTML-2.1] lays out a document without a viewport tag at the screen's width")
    func usesTheDevicesWidth() async throws {
        let shown = try await ShownDocument.show("<!doctype html><p>No viewport tag</p>", named: "Narrow.html")
        defer { shown.close() }
        let width = try await shown.json(
            [Double].self, "return [document.querySelector('p') ? 1 : 0, innerWidth, visualViewport.scale]")
        #expect(width.first == 1, "the reader renders the HTML")
        #expect(abs((width.dropFirst().first ?? 0) - ShownDocument.phone.width) < 1, "402 points wide: \(width)")
        #expect(abs((width.last ?? 0) - 1) < 0.01, "unzoomed: \(width)")
    }

    @Test("[HTML-2.1] follows the document's own viewport tag")
    func followsTheDocumentsViewport() async throws {
        let html = #"<!doctype html><meta name="viewport" content="width=600"><p>Own viewport tag</p>"#
        let shown = try await ShownDocument.show(html, named: "Own.html")
        defer { shown.close() }
        let width = try await shown.json(
            [Double].self, "return [document.querySelector('p') ? 1 : 0, document.documentElement.clientWidth]")
        #expect(width.first == 1, "the reader renders the HTML")
        #expect(abs((width.last ?? 0) - 600) < 1, "600 points wide: \(width)")
    }

    // MARK: Colors and sizes

    @Test("[HTML-3.1] keeps a document light in dark mode unless its own styles follow it")
    func keepsItsOwnColors() async throws {
        let html = """
            <!doctype html><style>@media (prefers-color-scheme: dark) { p.follows { color: rgb(200, 100, 0); } }</style>
            <p class="plain">Plain</p><p class="follows">Follows</p>
            """
        let shown = try await Self.show(html, style: .dark)
        defer { shown.close() }
        struct Page: Decodable {
            let dark: Bool
            let plain, follows: String?
        }
        let page = try await shown.json(
            Page.self,
            """
            const color = selector => { const e = document.querySelector(selector); return e ? getComputedStyle(e).color : null; };
            return { dark: matchMedia("(prefers-color-scheme: dark)").matches,
                     plain: color("p.plain"), follows: color("p.follows") };
            """)
        #expect(page.dark, "the page is shown in dark mode")
        #expect(page.plain == "rgb(0, 0, 0)", "unstyled text stays black")
        #expect(page.follows == "rgb(200, 100, 0)", "the document's own dark style applies")
    }

    @Test("[HTML-4.1] keeps the browser's default and the document's own text sizes, not the system's")
    func keepsItsOwnTextSizes() async throws {
        let html = """
            <!doctype html><p class="plain">Plain</p><p class="set" style="font-size: 20px">Set</p>
            <p class="system" style="font: -apple-system-body">System</p>
            """
        let shown = try await ShownDocument.show(html, named: "Sizes.html")
        defer { shown.close() }
        let sizes = try await shown.json(
            [Double].self,
            """
            return ["p.plain", "p.set", "p.system"].map(selector => {
              const e = document.querySelector(selector);
              return e ? parseFloat(getComputedStyle(e).fontSize) : 0;
            });
            """)
        #expect(sizes.count == 3 && sizes[2] > 16, "the system's text size differs from 16: \(sizes)")
        #expect(Array(sizes.prefix(2)) == [16, 20], "the browser's default and the document's size: \(sizes)")
    }

    // MARK: Dialogs

    @Test("[HTML-5.1] shows no alert, confirm, or prompt, and lets the script go on")
    func ignoresDialogs() async throws {
        let html = """
            <!doctype html><p>Dialogs</p>
            <script>
              alert("An alert");
              const confirmed = confirm("A question");
              const answer = prompt("A prompt", "default");
              document.body.dataset.result = JSON.stringify([confirmed, answer]);
            </script>
            """
        let shown = try await ShownDocument.show(html, named: "Dialogs.html")
        defer { shown.close() }
        try await shown.settle()
        let result = try await shown.evaluate("return document.body?.dataset.result ?? null")
        #expect(result as? String == "[false,null]", "confirm returns false and prompt null")
        #expect(shown.window.rootViewController?.presentedViewController == nil, "no dialog appears")
    }

    // MARK: Fixtures

    /// Shows `html` in a phone-sized window with the given appearance.
    private static func show(_ html: String, style: UIUserInterfaceStyle) async throws -> ShownDocument {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Page.html")
        try Data(html.utf8).write(to: file)
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

    private static func png(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData {
            context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
