import MarginReader
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// An open document, shown by the reader, with an offer of folder access when its page tries to
/// load files iOS keeps out of reach.
struct DocumentView: View {
    let fileURL: URL?

    @State private var reader: Reader?
    @State private var isPickingFolder = false
    @State private var offeredFolder: URL?

    var body: some View {
        Group {
            if let reader {
                WebView(reader.page)
            } else {
                Color(.systemBackground)
            }
        }
        // The system's title menu offers Rename, and Margin never changes a file.
        .toolbarTitleMenu { EmptyView() }
        .safeAreaInset(edge: .bottom) {
            if let folder = reader?.folderToOffer {
                Button("Allow Access to “\(folder.lastPathComponent)”") {
                    offeredFolder = folder
                    isPickingFolder = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 8)
            }
        }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let folder) = result, let reader else { return }
            try? FolderGrants.shared.grant(folder)
            Task { try? await reader.load() }
        }
        .fileDialogDefaultDirectory(offeredFolder)
        .task {
            guard reader == nil, let fileURL else { return }
            let reader = Reader(documentURL: fileURL)
            self.reader = reader
            try? await reader.load()
        }
    }
}
