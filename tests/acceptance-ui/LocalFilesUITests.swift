import XCTest

/// docs/specs/local-files/spec.md, through the app's interface, with files read as on a device.
@MainActor
final class LocalFilesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_LOCALFILES_2_1_offersTheDocumentsFolderAndOpensThePickerThere() throws {
        let browser = try DocumentBrowser.launch(
            with: [
                "Notes/Trip.md": Data("# Trip\n\nLychee orchard\n\n![photo](images/photo.png)\n".utf8),
                "Notes/images/photo.png": DocumentBrowser.photo(),
            ],
            arguments: DocumentBrowser.deviceSandbox)
        browser.open("Notes")
        browser.open("Trip")
        XCTAssertTrue(browser.readerShows("Lychee orchard"))
        XCTAssertFalse(browser.readerShowsImage("photo", timeout: 1), "the image is out of reach")
        let offer = browser.accessOffer(naming: "Notes")
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "the reader offers access to Notes")
        offer.tap()
        try assertPickerShows("Notes", listing: "images", in: browser)
    }

    func test_LOCALFILES_2_1_offersTheFolderHoldingTheDocumentAndTheBlockedFile() throws {
        let browser = try DocumentBrowser.launch(
            with: [
                "Trips/Notes/Trip.md": Data("# Trip\n\nMango orchard\n\n![photo](../Shared/photo.png)\n".utf8),
                "Trips/Shared/photo.png": DocumentBrowser.photo(),
            ],
            arguments: DocumentBrowser.deviceSandbox)
        browser.open("Trips")
        browser.open("Notes")
        browser.open("Trip")
        XCTAssertTrue(browser.readerShows("Mango orchard"))
        let offer = browser.accessOffer(naming: "Trips")
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "the reader offers access to Trips, not Notes")
        offer.tap()
        try assertPickerShows("Trips", listing: "Shared", in: browser)
    }

    func test_LOCALFILES_3_1_aGrantReloadsThePageAndLastsAcrossLaunches() throws {
        let browser = try DocumentBrowser.launch(
            with: [
                "Notes/Trip.md": Data("# Trip\n\nNectarine orchard\n\n![photo](images/photo.png)\n".utf8),
                "Notes/images/photo.png": DocumentBrowser.photo(),
                "Notes/Days/Day 1.md": Data("# Day 1\n\nOlive orchard\n\n![day](../images/photo.png)\n".utf8),
            ],
            arguments: DocumentBrowser.deviceSandbox)
        browser.open("Notes")
        browser.open("Trip")
        let offer = browser.accessOffer(naming: "Notes")
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "the reader offers access to Notes")
        offer.tap()
        try assertPickerShows("Notes", listing: "images", in: browser)
        browser.app.buttons["Open"].firstMatch.tap()
        XCTAssertTrue(browser.readerShowsImage("photo"), "the page reloads and shows the image")
        XCTAssertFalse(browser.anyAccessOffer.exists, "the offer is gone")

        try browser.relaunch()
        browser.open("Notes")
        browser.open("Trip")
        XCTAssertTrue(browser.readerShowsImage("photo"), "the grant lasts across launches")
        XCTAssertFalse(browser.anyAccessOffer.waitForExistence(timeout: 3), "no offer after relaunching")
        browser.close()

        browser.open("Days")
        browser.open("Day 1")
        XCTAssertTrue(browser.readerShowsImage("day"), "the grant covers another document in the folder")
        XCTAssertFalse(browser.anyAccessOffer.waitForExistence(timeout: 3), "no offer for it")
    }

    func test_LOCALFILES_4_1_offersNothingWhenNothingIsOutOfReach() throws {
        // Without the device sandbox, the simulator lets the app read every file, as in a granted folder.
        let readable = try DocumentBrowser.launch(with: [
            "Readable.md": Data("# Readable\n\nPeach orchard\n\n![photo](images/photo.png)\n".utf8),
            "images/photo.png": DocumentBrowser.photo(),
        ])
        readable.open("Readable")
        XCTAssertTrue(readable.readerShowsImage("photo"), "the reader shows the image")
        XCTAssertFalse(readable.anyAccessOffer.waitForExistence(timeout: 3), "no offer when the image is readable")
        readable.app.terminate()

        let plain = try DocumentBrowser.launch(
            with: ["Plain.md": Data("# Plain\n\nQuince orchard, and no image.\n".utf8)],
            arguments: DocumentBrowser.deviceSandbox)
        plain.open("Plain")
        XCTAssertTrue(plain.readerShows("Quince orchard"))
        XCTAssertFalse(plain.anyAccessOffer.waitForExistence(timeout: 3), "no offer when nothing is referenced")
    }

    /// Checks that the system folder picker is open in the folder `name`, listing `entry`.
    private func assertPickerShows(
        _ name: String, listing entry: String, in browser: DocumentBrowser,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let app = browser.app
        XCTAssertTrue(
            app.buttons["Open"].waitForExistence(timeout: 30), "the folder picker opens", file: file, line: line)
        let title = app.navigationBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ","))
            .firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the folder picker shows \(name)", file: file, line: line)
        XCTAssertTrue(browser.cell(entry).waitForExistence(timeout: 10), "it lists \(entry)", file: file, line: line)
    }
}
