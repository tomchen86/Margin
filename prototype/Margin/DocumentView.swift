import SwiftUI
import WebKit

struct DocumentView: View {
    let document: ViewerDocument
    let fileURL: URL?

    @Environment(FolderAccess.self) private var folderAccess
    @Environment(\.openURL) private var openURL

    @State private var model: ReaderModel?
    @State private var isFinding = false
    @State private var isPickingFolder = false
    @State private var suggestedFolder: URL?
    @State private var accessError: String?

    var body: some View {
        Group {
            if let model {
                WebView(model.page)
                    .webViewBackForwardNavigationGestures(.enabled)
                    .findNavigator(isPresented: $isFinding)
            } else {
                Color(.systemBackground)
            }
        }
        .toolbar {
            if let model {
                ToolbarItem(placement: .primaryAction) {
                    moreMenu(model)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let folder = model?.folderNeedingAccess(given: folderAccess) {
                accessButton(for: folder)
            }
        }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            grantAccess(result)
        }
        .fileDialogDefaultDirectory(suggestedFolder)
        .alert("無法讀取資料夾", isPresented: .constant(accessError != nil)) {
            Button("好") { accessError = nil }
        } message: {
            Text(accessError ?? "")
        }
        .task {
            guard model == nil else { return }
            let model = ReaderModel(document: document, fileURL: fileURL) { url in
                openURL(url)
            }
            self.model = model
            model.load()
        }
    }

    private func moreMenu(_ model: ReaderModel) -> some View {
        Menu {
            Button("尋找", systemImage: "magnifyingglass") {
                isFinding = true
            }
            Button(
                model.showsSource ? "顯示排版" : "顯示原始碼",
                systemImage: model.showsSource ? "doc.richtext" : "chevron.left.forwardslash.chevron.right"
            ) {
                model.toggleSource()
            }
            if let fileURL {
                ShareLink(item: fileURL)
            }
        } label: {
            Label("更多", systemImage: "ellipsis")
        }
    }

    private func accessButton(for folder: URL) -> some View {
        Button {
            suggestedFolder = folder
            isPickingFolder = true
        } label: {
            Label("允許讀取「\(folder.lastPathComponent)」來顯示圖片", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func grantAccess(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let folder):
            do {
                try folderAccess.grant(folder)
                model?.load()
            } catch {
                accessError = error.localizedDescription
            }
        case .failure(let error):
            accessError = error.localizedDescription
        }
    }
}
