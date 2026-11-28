import Foundation
import Testing

@testable import MarginReader

/// Which folder covers a file, which folder the reader offers, and which read errors mean a file
/// is out of reach.
@Suite struct LocalFileAccessTests {
    @Test func aFolderHoldsItsSubfoldersAndNothingBeside() {
        let notes = URL(filePath: "/a/Notes", directoryHint: .isDirectory)
        #expect(FolderGrants.folder(notes, holds: URL(filePath: "/a/Notes/images/photo.png")))
        #expect(FolderGrants.folder(notes, holds: URL(filePath: "/a/Notes/Days/../Trip.md")))
        #expect(!FolderGrants.folder(notes, holds: URL(filePath: "/a/Notes 2/photo.png")))
        #expect(!FolderGrants.folder(notes, holds: URL(filePath: "/a/Notes/../Shared/photo.png")))
    }

    @Test func offersTheDeepestFolderHoldingTheDocumentAndEveryBlockedFile() {
        let document = URL(filePath: "/a/Trips/Notes/Trip.md")
        #expect(Reader.folder(holding: document, and: []) == nil)
        #expect(
            Reader.folder(holding: document, and: [URL(filePath: "/a/Trips/Notes/images/photo.png")])?.path
                == "/a/Trips/Notes")
        #expect(
            Reader.folder(
                holding: document,
                and: [URL(filePath: "/a/Trips/Notes/images/photo.png"), URL(filePath: "/a/Trips/Shared/photo.png")]
            )?.path == "/a/Trips")
    }

    @Test func onlyPermissionErrorsMeanOutOfReach() {
        #expect(FileReading.isOutOfReach(CocoaError(.fileReadNoPermission)))
        #expect(FileReading.isOutOfReach(NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))))
        #expect(
            FileReading.isOutOfReach(
                NSError(
                    domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue,
                    userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))])))
        #expect(!FileReading.isOutOfReach(CocoaError(.fileReadNoSuchFile)))
        #expect(!FileReading.isOutOfReach(URLError(.fileDoesNotExist)))
    }
}
