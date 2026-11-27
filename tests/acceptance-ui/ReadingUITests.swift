import XCTest

/// docs/specs/reading/spec.md, through the app's interface.
@MainActor
final class ReadingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_READING_2_1_growsTextAtTheLargestTextSize() throws {
        let regular = try heights()
        let largest = try heights(
            arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for (name, height) in regular {
            let grown = try XCTUnwrap(largest[name])
            XCTAssertGreaterThan(grown, 2 * height, "\(name) grows from \(height) to more than twice that: \(grown)")
        }
    }

    /// Opens a Markdown file and a plain-text file in a new launch with `arguments`, and measures how
    /// tall each one's line of text is.
    private func heights(arguments: [String] = []) throws -> [String: CGFloat] {
        let texts = ["Prose": "Lychee orchard", "Plain": "Mango orchard"]
        let browser = try DocumentBrowser.launch(
            with: ["Prose.md": Data("# Prose\n\nLychee orchard\n".utf8), "Plain.txt": Data("Mango orchard".utf8)],
            arguments: arguments)
        defer { browser.app.terminate() }
        var heights: [String: CGFloat] = [:]
        for (name, text) in texts.sorted(by: { $0.key < $1.key }) {
            browser.open(name)
            XCTAssertTrue(browser.readerShows(text), "the reader shows \(name)")
            heights[name] =
                browser.app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
                .frame.height
            browser.close()
        }
        return heights
    }
}
