import XCTest

/// Margin's document browser, driven the way the owner uses it.
///
/// Test files go into a new folder of their own in "On My iPhone". On the simulator that folder is
/// a directory the test runner can write to and read back, so a test can also check that Margin
/// left the files alone.
@MainActor
struct DocumentBrowser {
    let app: XCUIApplication
    /// The test's folder, as the test runner sees it.
    let folder: URL

    /// Puts `files` (path in the folder → contents) into a new folder in On My iPhone, launches the
    /// app in English, and shows that folder in the document browser.
    static func launch(with files: [String: Data], file: StaticString = #filePath, line: UInt = #line) throws
        -> DocumentBrowser
    {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let storage = try onMyIPhone()
        // Earlier runs leave their folders behind on a reused simulator.
        for old in try FileManager.default.contentsOfDirectory(at: storage, includingPropertiesForKeys: nil)
        where old.lastPathComponent.hasPrefix(folderPrefix) {
            try? FileManager.default.removeItem(at: old)
        }
        let name = folderPrefix + UUID().uuidString.prefix(8)
        let folder = storage.appending(path: name, directoryHint: .isDirectory)
        for (path, contents) in files {
            let url = folder.appending(path: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url)
        }
        app.launch()
        let browser = DocumentBrowser(app: app, folder: folder)
        try browser.showFolder(named: name, file: file, line: line)
        return browser
    }

    static func launch(with files: [String: String], file: StaticString = #filePath, line: UInt = #line) throws
        -> DocumentBrowser
    {
        try launch(with: files.mapValues { Data($0.utf8) }, file: file, line: line)
    }

    /// The browser's cell for the file or folder whose name starts with `name`.
    func cell(_ name: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", name)).firstMatch
    }

    /// Taps the file whose name starts with `name`.
    func open(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let cell = cell(name)
        XCTAssertTrue(cell.waitForExistence(timeout: 30), "the browser lists \(name)", file: file, line: line)
        cell.tap()
    }

    /// Whether the reader shows `text` within `timeout` seconds. The default allows for a slow CI
    /// runner, where the system document browser can take more than 10 s to open a file.
    func readerShows(_ text: String, timeout: TimeInterval = 30) -> Bool {
        app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            .waitForExistence(timeout: timeout)
    }

    /// Closes the document and goes back to the browser.
    func close(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.navigationBars.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "the reader has a Back button", file: file, line: line)
        back.tap()
    }

    /// Every file and folder in the test's folder, with its contents and modification date.
    func snapshot() throws -> [String: Entry] {
        var entries: [String: Entry] = [:]
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys)
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: Set(keys))
            let contents = values.isDirectory == true ? nil : try Data(contentsOf: url)
            let path = String(url.path.dropFirst(folder.path.count))
            entries[path] = Entry(contents: contents, modified: values.contentModificationDate)
        }
        return entries
    }

    struct Entry: Equatable {
        let contents: Data?
        let modified: Date?
    }

    private static let folderPrefix = "Margin Acceptance "

    /// The directory behind "On My iPhone" on the simulator the tests run on.
    private static func onMyIPhone() throws -> URL {
        // The runner's home is <device>/data/Containers/Data/Application/<id>.
        let containers = URL(filePath: NSHomeDirectory()).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let groups = containers.appending(path: "Shared/AppGroup", directoryHint: .isDirectory)
        for group in try FileManager.default.contentsOfDirectory(at: groups, includingPropertiesForKeys: nil) {
            let metadata = group.appending(path: ".com.apple.mobile_container_manager.metadata.plist")
            if NSDictionary(contentsOf: metadata)?["MCMMetadataIdentifier"] as? String
                == "group.com.apple.FileProvider.LocalStorage"
            {
                return group.appending(path: "File Provider Storage", directoryHint: .isDirectory)
            }
        }
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: groups.path + " (On My iPhone)"])
    }

    /// Goes to Browse, up to its list of locations, then On My iPhone, then the folder `name`.
    private func showFolder(named name: String, file: StaticString, line: UInt) throws {
        let browse = app.buttons["Browse"].firstMatch
        XCTAssertTrue(browse.waitForExistence(timeout: 30), "the document browser shows", file: file, line: line)
        browse.tap()
        let onMyIPhone = app.staticTexts["On My iPhone"].firstMatch
        let up = app.buttons.matching(NSPredicate(format: "identifier == 'BackButton' AND label != 'Back'"))
            .firstMatch
        for _ in 0..<6 where !onMyIPhone.isHittable {
            guard up.waitForExistence(timeout: 2) else { break }
            up.tap()
        }
        XCTAssertTrue(onMyIPhone.waitForExistence(timeout: 5), "the browser lists On My iPhone", file: file, line: line)
        onMyIPhone.tap()
        let folder = cell(name)
        XCTAssertTrue(folder.waitForExistence(timeout: 30), "On My iPhone lists \(name)", file: file, line: line)
        folder.tap()
    }
}
