import Foundation

/// The one way the reader reads a file from disk: the document, or a file its page loads.
enum FileReading {
    /// The contents of `file`, read for the page of `document`. Reading the document uses its
    /// security scope; a file in a granted folder is readable through the grant.
    static func data(of file: URL, document: URL, grants: FolderGrants) throws -> Data {
        #if DEBUG
            if SandboxSimulation.isOn, !SandboxSimulation.allows(file, document: document, grants: grants) {
                throw CocoaError(.fileReadNoPermission, userInfo: [NSURLErrorKey: file, NSFilePathErrorKey: file.path])
            }
        #endif
        let isDocument = file.standardizedFileURL == document.standardizedFileURL
        let scoped = isDocument && document.startAccessingSecurityScopedResource()
        defer { if scoped { document.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: isDocument ? document : file)
    }

    /// Whether `error` means iOS keeps the file out of the app's reach, as opposed to the file not
    /// existing or not being readable for another reason.
    static func isOutOfReach(_ error: any Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == CocoaError.fileReadNoPermission.rawValue {
            return true
        }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(EPERM) || error.code == Int(EACCES) {
            return true
        }
        return (error.userInfo[NSUnderlyingErrorKey] as? NSError).map(isOutOfReach) ?? false
    }
}

#if DEBUG
    /// The test hook ADR-0004 calls for: with the launch argument `-SimulateSandbox`, files are
    /// readable as iOS allows on a device. The simulator does not enforce the sandbox for files
    /// outside the app, so then only the opened document, the app's bundle and container, and the
    /// granted folders are readable; any other read fails as on a device. Debug builds only.
    enum SandboxSimulation {
        static let isOn = ProcessInfo.processInfo.arguments.contains("-SimulateSandbox")

        static func allows(_ file: URL, document: URL, grants: FolderGrants) -> Bool {
            file.standardizedFileURL == document.standardizedFileURL
                || FolderGrants.folder(Bundle.main.bundleURL, holds: file)
                || FolderGrants.folder(URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory), holds: file)
                || grants.covers(file)
        }
    }
#endif
