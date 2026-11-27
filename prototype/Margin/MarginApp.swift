import SwiftUI

@main
struct MarginApp: App {
    @State private var folderAccess = FolderAccess()

    var body: some Scene {
        DocumentGroup(viewing: ViewerDocument.self) { file in
            DocumentView(document: file.document, fileURL: file.fileURL)
                .environment(folderAccess)
        }
    }
}
