import XCTest

/// docs/specs/links/spec.md, through the app's interface.
@MainActor
final class LinksUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Leaving Margin

    func test_LINKS_1_1_handsWebLinksToTheBrowser() throws {
        let browser = try openNotes(["Notes.md": "# Notes\n\nLychee orchard: [the web](https://margin.invalid/page)\n"])
        tapLink("the web", in: browser)
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30), "the default browser opens")
        browser.app.activate()
        XCTAssertTrue(browser.readerShows("Lychee orchard"), "the reader stays on the document")
    }

    func test_LINKS_1_1_handsOtherAppsAddressesToTheSystem() throws {
        let browser = try openNotes(["Notes.md": "# Notes\n\nLychee orchard: [a message](sms:5551234)\n"])
        tapLink("a message", in: browser)
        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        XCTAssertTrue(messages.wait(for: .runningForeground, timeout: 30), "Messages opens")
    }

    func test_LINKS_2_1_keepsWebFramesInThePage() throws {
        let browser = try openNotes([
            "Notes.md": "# Notes\n\nLychee orchard\n\n<iframe src=\"https://margin.invalid/embed\"></iframe>\n"
        ])
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertFalse(safari.wait(for: .runningForeground, timeout: 5), "the browser does not open")
        XCTAssertEqual(browser.app.state, .runningForeground, "Margin stays")
    }

    // MARK: Documents

    func test_LINKS_3_1_opensALinkedMarkdownFileAndGoesBack() throws {
        let browser = try openNotes([
            "Notes.md": "# Notes\n\nLychee orchard: [the other one](Other.md)\n",
            "Other.md": "# Other\n\nMango orchard\n",
        ])
        XCTAssertFalse(goBack(in: browser).exists, "no Go Back on the first page")
        tapLink("the other one", in: browser)
        XCTAssertTrue(browser.readerShows("Mango orchard"), "the reader shows Other.md")
        assertTitle("Other", in: browser)
        XCTAssertTrue(goBack(in: browser).waitForExistence(timeout: 10), "Go Back appears")
        goBack(in: browser).tap()
        XCTAssertTrue(browser.readerShows("Lychee orchard"), "back on Notes.md")
        assertTitle("Notes", in: browser)
    }

    func test_LINKS_3_1_opensALinkedHTMLFileAndGoesBack() throws {
        let browser = try openNotes([
            "Notes.md": "# Notes\n\nLychee orchard: [the page](Page.html)\n",
            "Page.html": "<!doctype html><title>Page</title><p>Kumquat orchard</p>\n",
        ])
        tapLink("the page", in: browser)
        XCTAssertTrue(browser.readerShows("Kumquat orchard"), "the reader shows Page.html")
        assertTitle("Page", in: browser)
        XCTAssertTrue(goBack(in: browser).waitForExistence(timeout: 10), "Go Back appears")
        goBack(in: browser).tap()
        XCTAssertTrue(browser.readerShows("Lychee orchard"), "back on Notes.md")
    }

    // MARK: Headings

    func test_LINKS_4_1_scrollsToAHeadingOnThePage() throws {
        let filler = (1...60).map { "Paragraph \($0) of filler." }.joined(separator: "\n\n")
        let browser = try openNotes([
            "Notes.md":
                "# Notes\n\nLychee orchard: [Jump to later](#later)\n\n\(filler)\n\n<h2 id=\"later\">Later</h2>\n\n\(filler)\n"
        ])
        tapLink("Jump to later", in: browser)
        try assertBelowTheToolbar("Later", in: browser)
    }

    func test_LINKS_4_1_scrollsToAHeadingInAnotherDocument() throws {
        let filler = (1...60).map { "Paragraph \($0) of filler." }.joined(separator: "\n\n")
        let browser = try openNotes([
            "Notes.md": "# Notes\n\nLychee orchard: [deep down](Other.md#deep)\n",
            "Other.md": "# Other\n\n\(filler)\n\n<h2 id=\"deep\">Deep</h2>\n\n\(filler)\n",
        ])
        tapLink("deep down", in: browser)
        try assertBelowTheToolbar("Deep", in: browser)
        assertTitle("Other", in: browser)
    }

    // MARK: Other files

    func test_LINKS_5_1_showsTextImagesAndOtherFiles() throws {
        let browser = try DocumentBrowser.launch(with: [
            "Notes.md": Data(
                "# Notes\n\nLychee orchard: [the text](notes.txt), [the photo](photo.png), [the archive](archive.zip)\n"
                    .utf8),
            "notes.txt": Data("Plain papaya notes".utf8),
            "photo.png": DocumentBrowser.photo(),
            "archive.zip": Data([0x50, 0x4B, 0x05, 0x06] + [UInt8](repeating: 0, count: 18)),
        ])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Lychee orchard"))
        tapLink("the text", in: browser)
        XCTAssertTrue(browser.readerShows("Plain papaya notes"), "a text file shows as its text")
        goBack(in: browser).tap()
        tapLink("the photo", in: browser)
        let image = browser.app.webViews.images.firstMatch
        let shown = NSPredicate { _, _ in image.exists && image.frame.width >= 150 }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: shown, object: nil)], timeout: 30), .completed,
            "an image shows as WebKit shows it")
        goBack(in: browser).tap()
        tapLink("the archive", in: browser)
        XCTAssertTrue(browser.readerShows("Margin can’t show “archive.zip”."), "any other file gets a message")
        XCTAssertTrue(goBack(in: browser).waitForExistence(timeout: 10), "with Go Back")
    }

    func test_LINKS_6_1_saysWhenALinkedFileIsMissing() throws {
        let browser = try openNotes(["Notes.md": "# Notes\n\nLychee orchard: [nothing](missing.md)\n"])
        tapLink("nothing", in: browser)
        XCTAssertTrue(browser.readerShows("Margin can’t find “missing.md”."), "the reader says the file is missing")
        goBack(in: browser).tap()
        XCTAssertTrue(browser.readerShows("Lychee orchard"), "Go Back returns to the document")
    }

    // MARK: Out of reach

    func test_LINKS_7_1_offersAccessThenOpensALinkOutOfReach() throws {
        let browser = try DocumentBrowser.launch(
            with: [
                "Trips/Notes/Trip.md": Data("# Trip\n\nLychee orchard: [day one](<../Days/Day 1.md>)\n".utf8),
                "Trips/Days/Day 1.md": Data("# Day 1\n\nMango orchard\n".utf8),
            ],
            arguments: DocumentBrowser.deviceSandbox)
        browser.open("Trips")
        browser.open("Notes")
        browser.open("Trip")
        XCTAssertTrue(browser.readerShows("Lychee orchard"))
        tapLink("day one", in: browser)
        let offer = browser.accessOffer(naming: "Trips")
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "the reader offers access to Trips")
        offer.tap()
        let open = browser.app.navigationBars.containing(.button, identifier: "Open").firstMatch.buttons["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 30), "the folder picker opens")
        open.tap()
        XCTAssertTrue(browser.readerShows("Mango orchard"), "once granted, the reader shows Day 1.md")
    }

    // MARK: Commands

    func test_LINKS_8_1_sharesThePageShown() throws {
        let other = "# Other\n\nMango **orchard**\n"
        let browser = try followToOther(other)
        choose("Share", in: browser)
        let sheet = browser.app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "the share sheet opens")
        let title = sheet.descendants(matching: .any)["LP.CaptionBar.TopCaption"].firstMatch
        let detail = sheet.descendants(matching: .any)["LP.CaptionBar.BottomCaption"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the share sheet names its item")
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "the share sheet describes its item")
        XCTAssertEqual(title.label, "Other", "Share offers the page shown")
        XCTAssertNotNil(
            detail.label.range(of: "\\b\(Data(other.utf8).count) byte", options: .regularExpression),
            "with Other.md's size: \(detail.label)")
    }

    func test_LINKS_8_1_showsTheSourceOfThePageShown() throws {
        let browser = try followToOther("# Other\n\nMango **orchard**\n")
        choose("View Source", in: browser)
        XCTAssertTrue(browser.readerShows("Mango **orchard**"), "the source is Other.md's")
    }

    /// Opens Notes.md and follows its link to Other.md, which holds `other`.
    private func followToOther(_ other: String, file: StaticString = #filePath, line: UInt = #line) throws
        -> DocumentBrowser
    {
        let browser = try openNotes(
            ["Notes.md": "# Notes\n\nLychee orchard: [the other one](Other.md)\n", "Other.md": other], file: file,
            line: line)
        tapLink("the other one", in: browser, file: file, line: line)
        XCTAssertTrue(browser.readerShows("Mango"), "the reader shows Other.md", file: file, line: line)
        return browser
    }

    // MARK: Helpers

    private func openNotes(_ files: [String: String], file: StaticString = #filePath, line: UInt = #line) throws
        -> DocumentBrowser
    {
        let browser = try DocumentBrowser.launch(with: files, file: file, line: line)
        browser.open("Notes", file: file, line: line)
        XCTAssertTrue(browser.readerShows("Lychee orchard"), "the reader shows Notes.md", file: file, line: line)
        return browser
    }

    private func tapLink(
        _ text: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line
    ) {
        let link = browser.app.webViews.links[text].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 30), "the page has the link \(text)", file: file, line: line)
        link.tap()
    }

    private func goBack(in browser: DocumentBrowser) -> XCUIElement {
        browser.app.buttons["Go Back"].firstMatch
    }

    private func assertTitle(
        _ name: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line
    ) {
        let title = browser.app.navigationBars.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the title names \(name)", file: file, line: line)
    }

    private func assertBelowTheToolbar(
        _ heading: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let element = browser.app.webViews.staticTexts[heading].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 30), "the page shows \(heading)", file: file, line: line)
        let toolbar = browser.app.navigationBars.firstMatch
        let placed = NSPredicate { _, _ in
            element.frame.minY >= toolbar.frame.maxY - 1 && element.frame.minY <= toolbar.frame.maxY + 100
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: placed, object: nil)], timeout: 10), .completed,
            "\(heading) is just below the toolbar: \(element.frame), toolbar \(toolbar.frame)", file: file, line: line)
    }

    private func choose(_ item: String, in browser: DocumentBrowser, file: StaticString = #filePath, line: UInt = #line)
    {
        let more = browser.app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the toolbar has a More menu", file: file, line: line)
        more.tap()
        let button = browser.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", item)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the More menu offers \(item)", file: file, line: line)
        button.tap()
    }
}
