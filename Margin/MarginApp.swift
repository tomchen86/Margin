import SwiftUI

@main
struct MarginApp: App {
    var body: some Scene {
        DocumentGroup(viewing: ViewerDocument.self) { file in
            DocumentView(fileURL: file.fileURL)
        }
    }
}
