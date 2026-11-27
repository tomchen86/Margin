#if targetEnvironment(simulator)
import Foundation
import Synchronization

/// The simulator doesn't enforce the iOS sandbox for files outside the app, so a
/// document's neighbours are always readable there — unlike on a real iPhone.
/// Launching with `-SimulateSandbox` mimics a device: only the opened document,
/// the app's own container and granted folders can be read.
nonisolated enum SandboxSimulation {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-SimulateSandbox")

    private static let grantedFolders = Mutex<[URL]>([])

    static func allow(_ folder: URL) {
        grantedFolders.withLock { $0.append(folder) }
    }

    static func checkReadable(_ url: URL) throws {
        guard isEnabled else { return }
        let roots = grantedFolders.withLock { $0 } + [URL.homeDirectory]
        guard roots.contains(where: { Paths.isInside(url, $0) }) else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSFilePathErrorKey: url.path])
        }
    }
}
#endif
