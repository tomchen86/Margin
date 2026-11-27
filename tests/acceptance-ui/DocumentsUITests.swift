import XCTest

/// docs/specs/documents/spec.md, through the app's interface.
@MainActor
final class DocumentsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_DOCUMENTS_1_1_opensEveryMarkdownExtension() throws {
        try opensEach([
            "Apricot.md": "Apricot orchard",
            "Banana.markdown": "Banana orchard",
            "Cherry.mdown": "Cherry orchard",
            "Damson.mkd": "Damson orchard",
            "Elder.mkdn": "Elder orchard",
            "README.MD": "Capital orchard",
        ])
    }

    func test_DOCUMENTS_1_1_opensHTML() throws {
        try opensEach([
            "Fig.html": "<!doctype html><title>Fig</title><p>Fig orchard</p>",
            "Grape.htm": "<!doctype html><title>Grape</title><p>Grape orchard</p>",
        ])
    }

    func test_DOCUMENTS_1_1_opensPlainTextSourceCodeAndLogs() throws {
        try opensEach([
            "Kiwi.txt": "Kiwi orchard",
            "Lemon.swift": "let lemon = \"Lemon orchard\"",
            "Mango.log": "12:00 Mango orchard",
        ])
    }

    func test_DOCUMENTS_1_1_opensJSONYAMLXMLAndFormatsBuiltOnThem() throws {
        try opensEach([
            "Nectarine.json": #"{"fruit": "Nectarine orchard"}"#,
            "Orange.yaml": "fruit: Orange orchard",
            "Peach.yml": "fruit: Peach orchard",
            "Quince.xml": #"<?xml version="1.0"?><fruit>Quince orchard</fruit>"#,
            "Tangerine.svg": #"<svg xmlns="http://www.w3.org/2000/svg"><text>Tangerine orchard</text></svg>"#,
            "Ugli.geojson": #"{"type": "Feature", "properties": {"name": "Ugli orchard"}}"#,
        ])
    }

    func test_DOCUMENTS_2_1_leavesOtherFilesClosed() throws {
        let browser = try DocumentBrowser.launch(with: [
            "Settings.toml": #"fruit = "Raspberry orchard""#,
            "Setup.ini": "[fruit]\nname = Strawberry orchard",
            "Letter.rtf": #"{\rtf1\ansi Vanilla orchard}"#,
        ])
        for name in ["Settings", "Setup", "Letter"] {
            let cell = browser.cell(name)
            XCTAssertTrue(cell.waitForExistence(timeout: 10))
            XCTAssertFalse(cell.isEnabled, "the browser shows \(name) as unavailable")
        }
        browser.cell("Settings").tap()
        XCTAssertFalse(browser.readerShows("orchard", timeout: 3), "no reader opens")
        XCTAssertTrue(browser.cell("Setup").exists, "the document browser stays")
    }

    func test_DOCUMENTS_4_1_writesNothingToTheFolder() throws {
        let browser = try DocumentBrowser.launch(with: [
            "Notes.md": Data("# Notes\n\nOlive orchard\n".utf8),
            "Other.txt": Data("Papaya orchard\n".utf8),
            "images/photo.png": Data(base64Encoded: Self.onePixelPNG)!,
        ])
        let before = try browser.snapshot()
        XCTAssertEqual(before.count, 4, "two files, a folder, and the image in it")
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Olive orchard"))
        browser.close()
        browser.open("Other")
        XCTAssertTrue(browser.readerShows("Papaya orchard"))
        browser.close()
        XCTAssertTrue(browser.cell("Notes").waitForExistence(timeout: 10), "back in the document browser")
        XCTAssertEqual(try browser.snapshot(), before, "same files, contents, and modification dates")
    }

    func test_DOCUMENTS_5_1_titleOffersNoFileActions() throws {
        let browser = try DocumentBrowser.launch(with: ["Notes.txt": "Quince orchard"])
        browser.open("Notes")
        XCTAssertTrue(browser.readerShows("Quince orchard"))
        let title = browser.app.navigationBars.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Notes'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the title names the file")
        title.tap()
        let fileAction = browser.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", ["Rename", "Move", "Duplicate"])).firstMatch
        XCTAssertFalse(
            fileAction.waitForExistence(timeout: 3),
            "the title offers no Rename, Move, or Duplicate, but shows \(fileAction.label)")
    }

    /// Opens each file from one folder and checks that the reader shows its words.
    private func opensEach(_ files: [String: String], file: StaticString = #filePath, line: UInt = #line) throws {
        let browser = try DocumentBrowser.launch(with: files, file: file, line: line)
        for (name, contents) in files.sorted(by: { $0.key < $1.key }) {
            let word = try XCTUnwrap(contents.firstMatch(of: /[A-Z][a-z]+ orchard/)).output
            browser.open(String(name.prefix { $0 != "." }), file: file, line: line)
            XCTAssertTrue(browser.readerShows(String(word)), "the reader shows \(name)", file: file, line: line)
            browser.close(file: file, line: line)
        }
    }

    private static let onePixelPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
}
