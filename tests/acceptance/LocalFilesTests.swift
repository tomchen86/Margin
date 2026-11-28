import Foundation
import Testing
import UIKit

/// docs/specs/local-files/spec.md, through the reader: a `Reader` showing a Markdown file in a window.
@MainActor
@Suite(.serialized)
struct LocalFilesTests {
    @Test("[LOCALFILES-1.1] shows images beside, below, and above the document, SVG included")
    func showsImagesNextToTheDocument() async throws {
        let markdown = "![photo](images/photo.png)\n\n![logo](../assets/logo.png)\n\n![diagram](diagram.svg)\n"
        let shown = try await ShownDocument.showing(
            files: [
                "Notes/Trip.md": Data(markdown.utf8),
                "Notes/images/photo.png": Self.png(width: 120, height: 60),
                "assets/logo.png": Self.png(width: 80, height: 40),
                "Notes/diagram.svg": Data(Self.svg.utf8),
            ],
            opening: "Notes/Trip.md")
        defer { shown.close() }
        #expect(try await shown.imageWidths() == ["photo": 120, "logo": 80, "diagram": 60])
    }

    @Test("[LOCALFILES-1.1] shows images whose names have spaces or other scripts")
    func showsImagesWithAnyName() async throws {
        let markdown = """
            ![spaced](<images/my photo.png>)

            ![chinese](%E5%9C%96%E7%89%87/%E7%9B%B8%E7%89%87.png)
            """
        let shown = try await ShownDocument.showing(
            files: [
                "Trip.md": Data(markdown.utf8),
                "images/my photo.png": Self.png(width: 120, height: 60),
                "圖片/相片.png": Self.png(width: 90, height: 45),
            ],
            opening: "Trip.md")
        defer { shown.close() }
        #expect(try await shown.imageWidths() == ["spaced": 120, "chinese": 90])
    }

    @Test("[LOCALFILES-1.1] ignores a query after the file name")
    func ignoresAQuery() async throws {
        let shown = try await ShownDocument.showing(
            files: [
                "Trip.md": Data("![query](images/photo.png?raw=true)\n".utf8),
                "images/photo.png": Self.png(width: 120, height: 60),
            ],
            opening: "Trip.md")
        defer { shown.close() }
        #expect(try await shown.imageWidths() == ["query": 120])
    }

    private static let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="60" height="30"><rect width="60" height="30" fill="teal"/></svg>
        """

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

extension ShownDocument {
    /// Writes `files` (path → contents) into a new folder of their own, then shows the one at `path`.
    fileprivate static func showing(files: [String: Data], opening path: String) async throws -> ShownDocument {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        for (name, contents) in files {
            let file = folder.appending(path: name)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: file)
        }
        return try await show(folder.appending(path: path))
    }

    /// Each image on the page, by its alternative text, with the width of the picture it loaded,
    /// or 0 when it loaded nothing.
    fileprivate func imageWidths() async throws -> [String: Int] {
        let script = """
            const images = [...document.images];
            await Promise.all(images.map(image => image.decode().catch(() => {})));
            return JSON.stringify(Object.fromEntries(
              images.map(image => [image.alt, image.complete ? image.naturalWidth : 0])));
            """
        let json = try #require(try await evaluate(script) as? String)
        return try JSONDecoder().decode([String: Int].self, from: Data(json.utf8))
    }
}
