import XCTest

/// docs/specs/reading/spec.md, finding in a page, through the app's interface.
@MainActor
final class FindUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_READING_5_1_findsFromTheMoreMenu() throws {
        let browser = try openNotes()
        let more = browser.app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the toolbar has a More menu")
        more.tap()
        let find = browser.app.buttons["Find"].firstMatch
        XCTAssertTrue(find.waitForExistence(timeout: 5), "the More menu offers Find")
        find.tap()
        try assertFinds("Lychee", count: "1 of 3", in: browser)
    }

    func test_READING_5_1_findsWithCommandF() throws {
        let browser = try openNotes()
        browser.app.typeKey("f", modifierFlags: .command)
        try assertFinds("Mango", count: "1 of 1", in: browser)
    }

    private func openNotes() throws -> DocumentBrowser {
        let browser = try DocumentBrowser.launch(with: ["Notes.txt": "Lychee one\nLychee two\nMango\nLychee three"])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Lychee one"))
        return browser
    }

    /// Checks that the system find bar is open, types `text`, and waits for it to report `count`.
    private func assertFinds(
        _ text: String, count: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let field = browser.app.searchFields["find.searchField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the system find bar opens", file: file, line: line)
        field.typeText(text)
        let result = browser.app.staticTexts["find.resultLabel"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "the find bar reports its matches", file: file, line: line)
        let counted = NSPredicate(format: "label == %@", count)
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: counted, object: result)], timeout: 10),
            .completed, "the find bar shows \(count), not \(result.label)", file: file, line: line)
    }
}
