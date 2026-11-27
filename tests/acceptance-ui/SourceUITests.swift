import XCTest

/// docs/specs/reading/spec.md, the source view, through the app's interface.
@MainActor
final class SourceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_READING_6_1_showsMarkdownSourceAndSwitchesBack() throws {
        let browser = try DocumentBrowser.launch(with: ["Notes.md": "# Title\n\nSome **bold** words.\n"])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Some"))
        try choose("View Source", in: browser)
        XCTAssertTrue(browser.readerShows("**bold**"), "the source shows the Markdown as typed")
        XCTAssertTrue(browser.readerShows("# Title"))
        try choose("View Rendered", in: browser)
        let gone = NSPredicate(format: "count == 0")
        let source = browser.app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS '**bold**'"))
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: gone, object: source)], timeout: 30), .completed,
            "the rendered page is back")
        XCTAssertTrue(browser.readerShows("Title"))
    }

    func test_READING_6_1_showsHTMLSourceWithoutRunningIt() throws {
        let html = #"<!doctype html><p>Kumquat</p><script>document.body.append("Pom" + "elo")</script>"#
        let browser = try DocumentBrowser.launch(with: ["Page.html": html])
        browser.open("Page")
        XCTAssertTrue(browser.readerShows("Kumquat"))
        try choose("View Source", in: browser)
        XCTAssertTrue(browser.readerShows("<p>Kumquat</p>"), "the source shows the markup as typed")
        XCTAssertTrue(browser.readerShows(#""Pom" + "elo""#), "and the script as typed")
        XCTAssertFalse(browser.app.webViews.staticTexts["Pomelo"].exists, "the script does not run")
    }

    func test_READING_6_1_offersNoSourceForPlainText() throws {
        let browser = try DocumentBrowser.launch(with: ["Notes.txt": "Lychee orchard"])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Lychee orchard"))
        let more = browser.app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the toolbar has a More menu")
        more.tap()
        XCTAssertTrue(browser.app.buttons["Find"].waitForExistence(timeout: 5), "the More menu is open")
        XCTAssertFalse(browser.app.buttons["View Source"].exists, "no View Source for plain text")
    }

    func test_READING_6_1_switchesToTheTopOfThePage() throws {
        let paragraphs = (1...80).map { "Paragraph \($0) of a long document." }.joined(separator: "\n\n")
        let browser = try DocumentBrowser.launch(with: ["Long.md": "# Long\n\n" + paragraphs + "\n"])
        browser.open("Long")
        XCTAssertTrue(browser.readerShows("Paragraph 1 of"))
        let page = browser.app.webViews.firstMatch
        for _ in 0..<6 { page.swipeUp() }
        let first = browser.app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Paragraph 1 of'"))
            .firstMatch
        XCTAssertLessThan(first.frame.minY, page.frame.minY, "scrolled far down")
        try choose("View Source", in: browser)
        try assertAtTop("# Long", of: page, in: browser)
        for _ in 0..<6 { page.swipeUp() }
        try choose("View Rendered", in: browser)
        try assertAtTop("Long", of: page, in: browser)
    }

    func test_READING_6_1_findSearchesTheSource() throws {
        let browser = try DocumentBrowser.launch(with: ["Notes.md": "Some **Lychee** words.\n"])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Lychee"))
        try choose("View Source", in: browser)
        XCTAssertTrue(browser.readerShows("**Lychee**"))
        browser.app.typeKey("f", modifierFlags: .command)
        let field = browser.app.searchFields["find.searchField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the system find bar opens")
        field.typeText("**")
        let result = browser.app.staticTexts["find.resultLabel"].firstMatch
        let counted = NSPredicate(format: "label == '1 of 2'")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: counted, object: result)], timeout: 10),
            .completed, "Find finds the source's characters")
    }

    /// Chooses `item` in the toolbar's More menu.
    private func choose(_ item: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line)
        throws
    {
        let more = browser.app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the toolbar has a More menu", file: file, line: line)
        more.tap()
        let button = browser.app.buttons[item].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the More menu offers \(item)", file: file, line: line)
        button.tap()
    }

    /// Checks that the page shows `text` at its top, in the top quarter of the page, below the toolbar.
    private func assertAtTop(
        _ text: String, of page: XCUIElement, in browser: DocumentBrowser, file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertTrue(browser.readerShows(text), "the page shows \(text)", file: file, line: line)
        let element = browser.app.webViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text))
            .firstMatch
        let top = NSPredicate { _, _ in
            element.exists && element.frame.minY >= page.frame.minY - 1
                && element.frame.minY < page.frame.minY + page.frame.height / 4
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: top, object: nil)], timeout: 10), .completed,
            "\(text) is at the top: \(element.frame) in \(page.frame)", file: file, line: line)
    }
}
