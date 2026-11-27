import XCTest

/// docs/specs/reading/spec.md, sharing, through the app's interface.
@MainActor
final class ShareUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_READING_7_1_sharesTheMarkdownFile() throws {
        try sharesTheFile(named: "Notes.md", contents: "# Notes\n\nLychee orchard\n", showing: "Lychee orchard")
    }

    func test_READING_7_1_sharesTheHTMLFile() throws {
        try sharesTheFile(
            named: "Page.html", contents: "<!doctype html><title>Page</title><p>Kumquat orchard</p>\n",
            showing: "Kumquat orchard")
    }

    /// Opens `name`, chooses Share, and checks that the share sheet holds the file itself: its name and
    /// its size in bytes, which a rendering of it would not have.
    private func sharesTheFile(
        named name: String, contents: String, showing text: String, file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let browser = try DocumentBrowser.launch(with: [name: contents])
        let base = String(name.prefix { $0 != "." })
        browser.open(base, file: file, line: line)
        XCTAssertTrue(browser.readerShows(text), "the reader shows \(name)", file: file, line: line)
        let more = browser.app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the toolbar has a More menu", file: file, line: line)
        more.tap()
        let share = browser.app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Share'")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5), "the More menu offers Share", file: file, line: line)
        share.tap()
        let sheet = browser.app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "the system share sheet opens", file: file, line: line)
        let title = sheet.descendants(matching: .any)["LP.CaptionBar.TopCaption"].firstMatch
        let detail = sheet.descendants(matching: .any)["LP.CaptionBar.BottomCaption"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the share sheet names its item", file: file, line: line)
        XCTAssertTrue(
            detail.waitForExistence(timeout: 10), "the share sheet describes its item", file: file, line: line)
        XCTAssertEqual(title.label, base, "it names the file", file: file, line: line)
        let size = Data(contents.utf8).count
        XCTAssertTrue(
            detail.label.range(of: "\\b\(size) byte", options: .regularExpression) != nil,
            "it shows the file's size, \(size) bytes: \(detail.label)", file: file, line: line)
    }
}
