import Foundation
import Observation
import WebKit

@Observable
final class ReaderModel {
    let page: WebPage
    let documentURL: URL?
    private(set) var showsSource = false
    /// Files the page referenced but the sandbox wouldn't let us read.
    private(set) var unreadableFiles: [URL] = []

    private let fallbackHTML: String

    init(document: ViewerDocument, fileURL: URL?, openExternally: @escaping (URL) -> Void) {
        let kind = document.kind(fileURL: fileURL)
        let sink = UnreadableFileSink()

        var configuration = WebPage.Configuration()
        if let fileURL, let scheme = URLScheme(LocalScheme.name) {
            let loader = DocumentLoader(documentURL: fileURL, documentData: document.data, documentKind: kind)
            configuration.urlSchemeHandlers[scheme] = LocalSchemeHandler(loader: loader) { url in
                Task { @MainActor in sink.model?.noteUnreadable(url) }
            }
        }
        // Markdown pages run the bundled renderer (their CSP blocks every other script); HTML files may run their own.
        configuration.defaultNavigationPreferences.allowsContentJavaScript = kind.runsScripts

        page = WebPage(configuration: configuration, navigationDecider: LinkPolicy(openExternally: openExternally))
        documentURL = fileURL
        fallbackHTML = ReaderPage.markdown(TextDecoding.string(from: document.data), title: "")
        sink.model = self
    }

    func load() {
        unreadableFiles = []
        guard let documentURL else {
            page.load(html: fallbackHTML)
            return
        }
        let events = page.load(URLRequest(url: LocalScheme.url(for: documentURL, source: showsSource)))
        #if DEBUG
        Task { [page] in
            for try await event in events {
                if case .finished = event { await RenderProbe.report(page) }
            }
        }
        #endif
    }

    func toggleSource() {
        showsSource.toggle()
        load()
    }

    /// The folder to ask for, if the page is missing files outside what we can read.
    func folderNeedingAccess(given access: FolderAccess) -> URL? {
        let blocked = unreadableFiles.filter { !access.covers($0) }
        guard !blocked.isEmpty, let documentURL else { return nil }
        return Paths.commonFolder(of: blocked + [documentURL])
    }

    fileprivate func noteUnreadable(_ url: URL) {
        guard !unreadableFiles.contains(url) else { return }
        unreadableFiles.append(url)
    }
}

private final class UnreadableFileSink {
    weak var model: ReaderModel?
}

extension DocumentKind {
    /// Markdown pages need the bundled renderer; HTML files may have scripts of their own.
    nonisolated var runsScripts: Bool { self != .plainText }
}

#if DEBUG
/// Spike instrumentation: logs how a rendered page came out, read with `log show`.
enum RenderProbe {
    static func report(_ page: WebPage) async {
        let script = """
            await document.fonts.ready;
            // On the CSP test page, also try what innerHTML can't: script elements created
            // through the DOM (which do execute) and a fetch of a neighbouring file.
            let csp = null;
            if (location.pathname.endsWith("Security.md")) {
              const violations = [];
              document.addEventListener("securitypolicyviolation", e => violations.push(`${e.violatedDirective} ${e.blockedURI || "inline"}`));
              const external = document.createElement("script");
              external.src = "evil.js";
              document.head.append(external);
              const inline = document.createElement("script");
              inline.textContent = "window.__pwned = 'dynamic inline script'";
              document.head.append(inline);
              let fetched;
              try { fetched = (await (await fetch("evil.js")).text()).length + " bytes"; } catch (e) { fetched = "blocked: " + e.message; }
              await new Promise(resolve => setTimeout(resolve, 500));
              csp = { violations, fetched };
            }
            const fonts = {};
            for (const face of document.fonts) {
              if (face.family.includes("KaTeX")) fonts[face.status] = (fonts[face.status] ?? 0) + 1;
            }
            return JSON.stringify({
              path: decodeURIComponent(location.pathname),
              readyMs: document.documentElement.dataset.readyMs ?? null,
              katex: document.querySelectorAll(".katex").length,
              katexErrors: document.querySelectorAll(".katex-error").length,
              katexFonts: fonts,
              highlightedTokens: document.querySelectorAll("pre code [class^=hljs-]").length,
              tasks: document.querySelectorAll("li.task").length,
              footnotes: document.querySelectorAll(".footnote-item").length,
              headingIDs: [...document.querySelectorAll("h1[id],h2[id],h3[id]")].slice(0, 4).map(h => h.id),
              pwned: window.__pwned ?? null,
              csp,
              bodyBackground: getComputedStyle(document.body).backgroundColor
            });
            """
        do {
            let result = try await page.callJavaScript(script)
            NSLog("MarginProbe %@", String(describing: result ?? "nil"))
        } catch {
            NSLog("MarginProbe error %@", String(describing: error))
        }
    }
}
#endif

/// Local pages stay in the viewer; web links go to Safari (or whichever app owns the URL).
struct LinkPolicy: WebPage.NavigationDeciding {
    let openExternally: (URL) -> Void

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }

        if url.scheme == LocalScheme.name {
            let kind = DocumentKind(fileURL: LocalScheme.fileURL(for: url))
            preferences.allowsContentJavaScript = kind.runsScripts && !LocalScheme.isSource(url)
            return .allow
        }
        if url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" {
            return .allow
        }
        // Subframes (embeds in HTML files) may load from the web; top-level navigation leaves the app.
        if action.target?.isMainFrame ?? true {
            openExternally(url)
            return .cancel
        }
        return .allow
    }
}
