import MarginReader
import SwiftUI
import WebKit

/// An open document, shown by the reader.
struct DocumentView: View {
    let fileURL: URL?

    @State private var reader: Reader?

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
        .task {
            guard reader == nil, let fileURL else { return }
            let reader = Reader(documentURL: fileURL)
            self.reader = reader
            try? await reader.load()
        }
    }
}
