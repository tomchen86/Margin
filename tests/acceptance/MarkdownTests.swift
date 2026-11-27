import Foundation
import MarginReader
import Testing
import UIKit
import WebKit

/// docs/specs/markdown/spec.md, through the reader: a `Reader` showing a Markdown file in a window.
@MainActor
@Suite(.serialized)
struct MarkdownTests {
    // MARK: CommonMark

    @Test("[MARKDOWN-1.1] renders headings, emphasis, code, links, images, lists, quotes, and rules")
    func rendersBlocksAndEmphasis() async throws {
        let markdown = """
            # Title

            ## Part

            Some *emphasis*, **strong**, and `code`, a [link](https://example.com/page), \
            and ![a cat](https://margin.invalid/cat.png).

            - one
            - two

            3. three
            4. four

            > quoted

            ```
            fenced code
            ```

                indented code

            ***
            """
        let shown = try await ShownDocument.show(markdown, named: "Blocks.md")
        defer { shown.close() }
        struct Page: Decodable {
            let h1, h2, em, strong, code, link, image: String?
            let bullets, numbers, codeBlocks: [String]
            let start: Int?
            let quote: String?
            let rules: Int
        }
        let page = try await shown.json(
            Page.self,
            """
            const text = selector => document.querySelector(selector)?.textContent.trim() ?? null;
            const all = selector => [...document.querySelectorAll(selector)].map(e => e.textContent.trim());
            return {
              h1: text("h1"), h2: text("h2"), em: text("em"), strong: text("strong"), code: text("p code"),
              link: text('a[href="https://example.com/page"]'),
              image: document.querySelector('img[src="https://margin.invalid/cat.png"]')?.alt ?? null,
              bullets: all("ul > li"), numbers: all("ol > li"), start: document.querySelector("ol")?.start ?? null,
              quote: text("blockquote"), codeBlocks: all("pre code"), rules: document.querySelectorAll("hr").length
            };
            """)
        #expect(page.h1 == "Title")
        #expect(page.h2 == "Part")
        #expect(page.em == "emphasis")
        #expect(page.strong == "strong")
        #expect(page.code == "code")
        #expect(page.link == "link")
        #expect(page.image == "a cat")
        #expect(page.bullets == ["one", "two"])
        #expect(page.numbers == ["three", "four"])
        #expect(page.start == 3)
        #expect(page.quote == "quoted")
        #expect(page.codeBlocks == ["fenced code", "indented code"])
        #expect(page.rules == 1)
    }

    @Test("[MARKDOWN-1.1] shows a single newline as a space, and breaks lines at two spaces or a backslash")
    func breaksLines() async throws {
        let markdown = "one\ntwo\n\nthree  \nfour\\\nfive"
        let shown = try await ShownDocument.show(markdown, named: "Breaks.md")
        defer { shown.close() }
        let paragraphs = try await shown.json(
            [String].self, "return [...document.querySelectorAll('p')].map(p => p.innerText)")
        #expect(paragraphs == ["one two", "three\nfour\nfive"])
    }

    @Test("[MARKDOWN-1.1] shows quotes, dashes, and dots as typed")
    func keepsPunctuation() async throws {
        let shown = try await ShownDocument.show(#""double" 'single' -- ... (c)"#, named: "Punctuation.md")
        defer { shown.close() }
        let paragraphs = try await shown.evaluate("return document.querySelectorAll('p').length")
        #expect(paragraphs as? Int == 1, "the reader renders the line as a paragraph")
        #expect(
            try await shown.visibleText().trimmingCharacters(in: .whitespacesAndNewlines)
                == #""double" 'single' -- ... (c)"#)
    }

    @Test("[MARKDOWN-1.1] shows escaped characters and entities")
    func showsEscapesAndEntities() async throws {
        let shown = try await ShownDocument.show(#"\*not emphasis\* &copy; &amp;"#, named: "Escapes.md")
        defer { shown.close() }
        #expect(try await shown.visibleText().trimmingCharacters(in: .whitespacesAndNewlines) == "*not emphasis* © &")
        #expect(try await shown.boldOrItalicText() == [])
    }

    @Test("[MARKDOWN-1.1] renders HTML in the document")
    func rendersHTML() async throws {
        let markdown = """
            Press <kbd>⌘K</kbd> to search, in <span style="color: rgb(255, 0, 0)">red</span>.

            <details>
            <summary>More</summary>

            Hidden text

            </details>
            """
        let shown = try await ShownDocument.show(markdown, named: "HTML.md")
        defer { shown.close() }
        struct Page: Decodable {
            let key, color: String?
            let closed: Bool?
            let summary: String?
        }
        let page = try await shown.json(
            Page.self,
            """
            const span = [...document.querySelectorAll("span")].find(s => s.textContent === "red");
            const details = document.querySelector("details");
            return {
              key: document.querySelector("kbd")?.textContent ?? null,
              color: span ? getComputedStyle(span).color : null,
              closed: details ? !details.open : null,
              summary: details?.querySelector("summary")?.textContent ?? null
            };
            """)
        #expect(page.key == "⌘K")
        #expect(page.color == "rgb(255, 0, 0)")
        #expect(page.closed == true)
        #expect(page.summary == "More")
    }

    // MARK: GitHub extensions

    @Test("[MARKDOWN-2.1] shows a table with a header row and aligned columns")
    func showsTables() async throws {
        let markdown = """
            | Left | Center | Right |
            |:-----|:------:|------:|
            | a | **b** | c \\| d |
            | short |
            """
        let shown = try await ShownDocument.show(markdown, named: "Table.md")
        defer { shown.close() }
        struct Table: Decodable {
            let header: [String]
            let rows: [[String]]
            let headerAlignment: [String]
            let bodyAlignment: [String]
            let bold: String?
        }
        let table = try await shown.json(
            Table.self,
            """
            const table = document.querySelector("table");
            if (!table) return { header: [], rows: [], headerAlignment: [], bodyAlignment: [], bold: null };
            const cells = row => [...row.cells];
            const head = table.tHead?.rows[0] ?? table.rows[0];
            const body = [...table.rows].filter(row => row !== head);
            return {
              header: cells(head).map(c => c.textContent.trim()),
              rows: body.map(row => cells(row).map(c => c.textContent.trim())),
              headerAlignment: cells(head).map(c => getComputedStyle(c).textAlign),
              bodyAlignment: cells(body[0]).map(c => getComputedStyle(c).textAlign),
              bold: body[0].cells[1].querySelector("strong, b")?.textContent ?? null
            };
            """)
        #expect(table.header == ["Left", "Center", "Right"])
        #expect(table.rows == [["a", "b", "c | d"], ["short", "", ""]])
        #expect(table.headerAlignment == ["left", "center", "right"])
        #expect(table.bodyAlignment == ["left", "center", "right"])
        #expect(table.bold == "b")
    }

    @Test("[MARKDOWN-3.1] strikes through text between two tildes, not one")
    func strikesThroughDoubleTildes() async throws {
        let shown = try await ShownDocument.show("~~gone~~ and ~one~, about ~5 min", named: "Strike.md")
        defer { shown.close() }
        let struck = try await shown.json(
            [String].self,
            """
            const struck = [];
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (!node.data.trim()) continue;
              for (let e = node.parentElement; e; e = e.parentElement) {
                if (getComputedStyle(e).textDecorationLine.includes("line-through")) { struck.push(node.data); break; }
              }
            }
            return struck;
            """)
        #expect(struck == ["gone"])
        #expect(try await shown.visibleText().contains("~one~, about ~5 min"))
    }

    @Test("[MARKDOWN-4.1] shows task list items as disabled checkboxes that tapping does not change")
    func showsTaskLists() async throws {
        let markdown = """
            - [ ] open
            - [x] done
            - [X] also done

            1. [ ] numbered

            - not [ ] a task
            - [ ]no space
            """
        let shown = try await ShownDocument.show(markdown, named: "Tasks.md")
        defer { shown.close() }
        struct Box: Decodable {
            let checked, disabled, checkedAfterTap: Bool
            let item: String
        }
        let boxes = try await shown.json(
            [Box].self,
            """
            return [...document.querySelectorAll('input[type="checkbox"]')].map(box => {
              const checked = box.checked;
              box.click();
              return { checked, disabled: box.disabled, checkedAfterTap: box.checked,
                       item: box.closest("li")?.textContent.trim() ?? "" };
            });
            """)
        #expect(boxes.map(\.item) == ["open", "done", "also done", "numbered"])
        #expect(boxes.map(\.checked) == [false, true, true, false])
        #expect(boxes.allSatisfy { $0.disabled })
        #expect(boxes.allSatisfy { $0.checked == $0.checkedAfterTap }, "tapping a checkbox changes nothing")
        let text = try await shown.visibleText()
        #expect(text.contains("not [ ] a task"))
        #expect(text.contains("[ ]no space"))
    }

    @Test("[MARKDOWN-5.1] links bare https:, http:, and www. addresses and e-mail addresses, not bare domains")
    func linksBareAddresses() async throws {
        let markdown = """
            Visit https://example.com/a?b=1, www.example.com, and <https://example.org/x>.
            Mail someone@example.com (see https://example.net/p) or http://example.edu.

            Not links: example.com, README.md, and `https://code.example.com`.
            """
        let shown = try await ShownDocument.show(markdown, named: "Links.md")
        defer { shown.close() }
        struct Link: Decodable, Equatable {
            let href, text: String
        }
        let links = try await shown.json(
            [Link].self,
            "return [...document.querySelectorAll('a[href]')].map(a => ({ href: a.getAttribute('href'), text: a.textContent }))"
        )
        #expect(
            links == [
                Link(href: "https://example.com/a?b=1", text: "https://example.com/a?b=1"),
                Link(href: "http://www.example.com", text: "www.example.com"),
                Link(href: "https://example.org/x", text: "https://example.org/x"),
                Link(href: "mailto:someone@example.com", text: "someone@example.com"),
                Link(href: "https://example.net/p", text: "https://example.net/p"),
                Link(href: "http://example.edu", text: "http://example.edu"),
            ])
    }

    @Test("[MARKDOWN-6.1] numbers footnotes in reference order and lists them at the end, linked both ways")
    func showsFootnotes() async throws {
        let markdown = """
            First claim[^1], second claim[^note], first again[^1], and missing[^nope].

            Closing paragraph.

            [^note]: The named note.
            [^1]: The numbered note.
            """
        let shown = try await ShownDocument.show(markdown, named: "Footnotes.md")
        defer { shown.close() }
        struct Reference: Decodable {
            let number: String
            let superscript: Bool
            let note: String?
            let noteAfterText: Bool
            let backLinkTarget: Bool
        }
        let references = try await shown.json(
            [Reference].self,
            """
            const text = [...document.querySelectorAll("p")].find(p => p.textContent.includes("Closing paragraph"));
            return [...document.querySelectorAll('a[href^="#"]')]
              .filter(a => a.closest("p") && a.closest("p").textContent.includes("First claim"))
              .map(a => {
                const note = document.getElementById(decodeURIComponent(a.getAttribute("href").slice(1)));
                const back = note ? [...note.querySelectorAll('a[href^="#"]')]
                  .map(b => document.getElementById(decodeURIComponent(b.getAttribute("href").slice(1)))) : [];
                return {
                  number: a.textContent.trim(),
                  superscript: !!a.closest("sup") || getComputedStyle(a).verticalAlign === "super",
                  note: note ? note.textContent.replace(/\\s+/g, " ").trim() : null,
                  noteAfterText: !!(note && text && (text.compareDocumentPosition(note) & Node.DOCUMENT_POSITION_FOLLOWING)),
                  backLinkTarget: back.some(target => target && target.closest("p") === a.closest("p"))
                };
              });
            """)
        #expect(
            references.map { $0.number.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) } == ["1", "2", "1"])
        #expect(references.allSatisfy { $0.superscript })
        #expect(references.map { $0.note?.contains("The numbered note.") } == [true, false, true])
        #expect(references[1].note?.contains("The named note.") == true)
        #expect(references.allSatisfy { $0.noteAfterText }, "the notes come after the rest of the document")
        #expect(references.allSatisfy { $0.backLinkTarget }, "each note links back to a reference")
        let order = try await shown.json(
            [Int].self,
            """
            const all = document.body.innerText;
            return [all.lastIndexOf("The numbered note."), all.lastIndexOf("The named note.")];
            """)
        #expect(order[0] >= 0 && order[0] < order[1], "the note referenced first is listed first")
        #expect(try await shown.visibleText().contains("[^nope]"))
    }

    @Test("[MARKDOWN-7.1] shows front matter as typed in a monospaced block at the top")
    func showsFrontMatter() async throws {
        let markdown = "---\ntitle: Notes\ntags: [a, b]\n---\n# Heading\n\nBody text."
        let shown = try await ShownDocument.show(markdown, named: "Front.md")
        defer { shown.close() }
        let text = try await shown.visibleText()
        #expect(text.hasPrefix("title: Notes\ntags: [a, b]"))
        #expect(!text.contains("---"))
        let family = try #require(try await shown.style("font-family", of: "title: Notes"))
        #expect(family.contains("monospace"), "monospaced: \(family)")
        struct Page: Decodable {
            let h1: String?
            let otherHeadings, rules: Int
        }
        let page = try await shown.json(
            Page.self,
            """
            return { h1: document.querySelector("h1")?.textContent ?? null,
                     otherHeadings: document.querySelectorAll("h2, h3, h4, h5, h6").length,
                     rules: document.querySelectorAll("hr").length };
            """)
        #expect(page.h1 == "Heading")
        #expect(page.otherHeadings == 0)
        #expect(page.rules == 0)
    }

    @Test("[MARKDOWN-7.1] shows a first line of --- without a closing line as a rule")
    func showsUnclosedFrontMatterAsRule() async throws {
        let shown = try await ShownDocument.show("---\nJust a paragraph.\n\nAnother.", named: "Rule.md")
        defer { shown.close() }
        let page = try await shown.json(
            [Int].self,
            "return [document.querySelectorAll('hr').length, document.querySelectorAll('p').length]")
        #expect(page == [1, 2])
    }

    // MARK: Page policy

    @Test("[MARKDOWN-8.1] runs none of a document's scripts, handlers, or javascript: links")
    func runsNoDocumentScripts() async throws {
        let mark = "document.documentElement.dataset.ran"
        let markdown = """
            <script>\(mark) = "inline script"</script>
            <script src="evil.js"></script>

            <img src="https://margin.invalid/missing.png" onerror="\(mark) = 'onerror'">
            <svg onload="\(mark) = 'svg onload'"></svg>
            <details open ontoggle="\(mark) = 'ontoggle'"><summary>s</summary>d</details>

            <a id="raw" href="javascript:\(mark)='javascript link'">raw link</a>
            and [markdown link](javascript:void(0))
            """
        let shown = try await ShownDocument.show(
            files: ["Evil.md": Data(markdown.utf8), "evil.js": Data("\(mark) = \"evil.js\"".utf8)],
            opening: "Evil.md")
        defer { shown.close() }
        let raw = try await shown.evaluate("return document.getElementById('raw')?.tagName ?? null")
        #expect(raw as? String == "A", "the reader renders the document's HTML")
        try await shown.settle()
        _ = try await shown.evaluate("document.getElementById('raw')?.click(); return true")
        try await shown.settle()
        let ran = try await shown.evaluate("return document.documentElement.dataset.ran ?? null")
        #expect(ran as? String == nil, "nothing from the document ran: \(String(describing: ran))")
        let javascriptLinks = try await shown.evaluate(
            "return [...document.querySelectorAll('a[href^=\"javascript:\" i]')].filter(a => a.id !== 'raw').length")
        #expect(javascriptLinks as? Int == 0, "a Markdown link to javascript: is not a link")
        #expect(try await shown.policyRefuses("script", ["src": "evil.js"]))
        #expect(try await shown.policyRefuses("script", ["src": "https://margin.invalid/evil.js"]))
    }

    @Test("[MARKDOWN-8.1] loads no srcdoc, local, http:, or data: frame and no embedded object")
    func loadsNoUnsafeFrames() async throws {
        let markdown = """
            Frames:

            <iframe id="srcdoc" srcdoc="<p>srcdoc frame</p>"></iframe>
            <iframe id="local" src="Other.md"></iframe>
            """
        let shown = try await ShownDocument.show(
            files: ["Frames.md": Data(markdown.utf8), "Other.md": Data("Other document".utf8)],
            opening: "Frames.md")
        defer { shown.close() }
        let paragraph = try await shown.evaluate("return document.querySelector('p')?.textContent ?? null")
        #expect(paragraph as? String == "Frames:", "the reader renders the document")
        try await shown.settle()
        let framed = try await shown.json(
            [String].self,
            """
            return [...document.querySelectorAll("iframe")].map(frame => {
              try { return frame.contentDocument?.body?.textContent ?? ""; } catch { return ""; }
            });
            """)
        #expect(framed.allSatisfy { !$0.contains("srcdoc frame") && !$0.contains("Other document") })
        let sibling = try #require(
            try await shown.evaluate("return new URL('Other.md', location.href).href") as? String)
        #expect(try await shown.policyRefuses("iframe", ["src": sibling]), "a frame of a file next to it")
        #expect(try await shown.policyRefuses("iframe", ["src": "http://margin.invalid/"]), "an http: frame")
        #expect(try await shown.policyRefuses("iframe", ["src": "data:text/html,<p>data frame</p>"]), "a data: frame")
        #expect(try await shown.policyRefuses("object", ["data": "https://margin.invalid/movie.swf"]))
        #expect(try await shown.policyRefuses("embed", ["src": "https://margin.invalid/movie.swf"]))
    }

    @Test("[MARKDOWN-9.1] lets web images, media, and https: frames load, and shows data: images")
    func loadsWebContent() async throws {
        let png = try #require(Self.image(width: 40, height: 20).pngData()).base64EncodedString()
        let markdown = """
            ![web](https://margin.invalid/web.png)

            ![embedded](data:image/png;base64,\(png))

            <iframe id="web" src="https://margin.invalid/embed"></iframe>
            """
        let shown = try await ShownDocument.show(markdown, named: "Web.md")
        defer { shown.close() }
        struct Page: Decodable {
            let webImage, frame: String?
            let embeddedWidth: Int?
        }
        let page = try await shown.json(
            Page.self,
            """
            const embedded = document.querySelector('img[alt="embedded"]');
            return { webImage: document.querySelector('img[alt="web"]')?.getAttribute("src") ?? null,
                     frame: document.getElementById("web")?.getAttribute("src") ?? null,
                     embeddedWidth: embedded && embedded.complete ? embedded.naturalWidth : null };
            """)
        #expect(page.webImage == "https://margin.invalid/web.png", "the web image stays in the page")
        #expect(page.frame == "https://margin.invalid/embed", "the https: frame stays in the page")
        #expect(page.embeddedWidth == 40, "the data: image shows")
        #expect(try await !shown.policyRefuses("img", ["src": "https://margin.invalid/a.png"]))
        #expect(try await !shown.policyRefuses("img", ["src": "http://margin.invalid/a.png"]))
        #expect(try await !shown.policyRefuses("video", ["src": "https://margin.invalid/a.mp4"]))
        #expect(try await !shown.policyRefuses("audio", ["src": "http://margin.invalid/a.mp3"]))
        #expect(try await !shown.policyRefuses("iframe", ["src": "https://margin.invalid/embed2"]))
    }

    @Test("[MARKDOWN-9.1] the app allows http: loads for web content only")
    func allowsHTTPForWebContentOnly() throws {
        let security = try #require(
            Bundle.main.infoDictionary?["NSAppTransportSecurity"] as? [String: Any], "the app declares its ATS settings"
        )
        #expect(security["NSAllowsArbitraryLoadsInWebContent"] as? Bool == true)
        #expect(security["NSAllowsArbitraryLoads"] as? Bool != true)
    }

    @Test("[MARKDOWN-10.1] loads its own scripts and styles from the app, and nothing of its own from the web")
    func loadsNothingFromTheNetwork() async throws {
        let shown = try await ShownDocument.show("# Title\n\nA paragraph of *plain* words.", named: "Local.md")
        defer { shown.close() }
        let heading = try await shown.evaluate("return document.querySelector('h1')?.textContent ?? null")
        #expect(heading as? String == "Title", "the page is rendered Markdown")
        let scripts = try await shown.json(
            [String].self, "return [...document.querySelectorAll('script[src]')].map(script => script.src)")
        let styles = try await shown.json(
            [String].self, "return [...document.querySelectorAll('link[href]')].map(link => link.href)")
        #expect(!scripts.isEmpty, "the page runs the app's renderer")
        #expect((scripts + styles).allSatisfy { $0.hasPrefix("margin://app/") }, "from the app: \(scripts + styles)")
        #expect(try await shown.policyRefuses("script", ["src": "https://margin.invalid/library.js"]))
        #expect(
            try await shown.policyRefuses("link", ["rel": "stylesheet", "href": "https://margin.invalid/style.css"]))
        #expect(
            try await shown.policyRefuses(
                running: "new FontFace('Probe', 'url(https://margin.invalid/font.woff2)').load().catch(() => {});"))
        #expect(try await shown.policyRefuses(running: "fetch('https://margin.invalid/data').catch(() => {});"))
    }

    // MARK: Layout

    @Test("[MARKDOWN-11.1] shows a wide page's text in a centered column 42 times the text size")
    func keepsAReadableColumn() async throws {
        let iPad = CGSize(width: 1194, height: 834)
        let shown = try await ShownDocument.show(Self.longParagraph, named: "Column.md", in: iPad)
        defer { shown.close() }
        let column = try await shown.paragraphBox()
        #expect(abs(column.width - 42 * column.fontSize) <= 1, "42 times the text size: \(column)")
        #expect(abs(column.left - column.right) <= 1, "centered: \(column)")
    }

    @Test("[MARKDOWN-11.1] spans a phone's page apart from margins of at most 24 points")
    func spansAPhonePage() async throws {
        let shown = try await ShownDocument.show(Self.longParagraph, named: "Column.md")
        defer { shown.close() }
        let column = try await shown.paragraphBox()
        #expect(column.left >= 0 && column.left <= 24, "left margin: \(column)")
        #expect(column.right >= 0 && column.right <= 24, "right margin: \(column)")
    }

    @Test("[MARKDOWN-12.1] scrolls a wide table and a long code line inside themselves, never the page")
    func scrollsWideContentInside() async throws {
        let columns = (1...20).map { "column-\($0)" }
        let table = [
            "| " + columns.joined(separator: " | ") + " |",
            "|" + String(repeating: "---|", count: 20),
            "| " + columns.joined(separator: " | ") + " |",
        ].joined(separator: "\n")
        let code = "```\n" + String(repeating: "x", count: 300) + "\n```"
        let url = "https://example.com/" + String(repeating: "a", count: 180)
        let word = String(repeating: "w", count: 200)
        let markdown = "\(table)\n\n\(code)\n\nLink \(url) and \(word) end.\n"
        let shown = try await ShownDocument.show(markdown, named: "Wide.md")
        defer { shown.close() }
        struct Page: Decodable {
            let pageWidth, pageScrollWidth: Double
            let tableScrolls, codeScrolls: Bool
            let paragraphRight: Double
        }
        let page = try await shown.json(
            Page.self,
            """
            const scrollsInside = element => {
              for (let e = element; e && e !== document.body; e = e.parentElement) {
                const overflow = getComputedStyle(e).overflowX;
                if ((overflow === "auto" || overflow === "scroll") && e.scrollWidth > e.clientWidth
                    && e.getBoundingClientRect().right <= innerWidth) return true;
              }
              return false;
            };
            const paragraph = [...document.querySelectorAll("p")].find(p => p.textContent.startsWith("Link"));
            const range = document.createRange();
            if (paragraph) range.selectNodeContents(paragraph);
            const right = paragraph ? Math.max(...[...range.getClientRects()].map(r => r.right)) : 1e9;
            return { pageWidth: innerWidth, pageScrollWidth: document.documentElement.scrollWidth,
                     tableScrolls: scrollsInside(document.querySelector("table")),
                     codeScrolls: scrollsInside(document.querySelector("pre")),
                     paragraphRight: right };
            """)
        #expect(page.tableScrolls, "the table scrolls sideways inside itself")
        #expect(page.codeScrolls, "the code block scrolls sideways inside itself")
        #expect(page.paragraphRight <= page.pageWidth, "the paragraph wraps within the page")
        #expect(page.pageScrollWidth <= page.pageWidth, "the page does not scroll sideways")
    }

    @Test("[MARKDOWN-13.1] shrinks an image wider than the column, keeping its proportions")
    func shrinksWideImages() async throws {
        let png = try #require(Self.image(width: 2000, height: 100).pngData()).base64EncodedString()
        let markdown = "Before the image.\n\n![wide](data:image/png;base64,\(png))\n\n\(Self.longParagraph)"
        let shown = try await ShownDocument.show(markdown, named: "Image.md")
        defer { shown.close() }
        let column = try await shown.paragraphBox()
        let image = try await shown.json(
            [Double].self,
            """
            const image = document.querySelector('img[alt="wide"]');
            if (!image) return [-1, -1];
            const box = image.getBoundingClientRect();
            return [box.width, box.height];
            """)
        #expect(abs(image[0] - column.width) <= 1, "as wide as the column: \(image), \(column)")
        #expect(abs(image[1] - image[0] / 20) <= 1, "a twentieth as tall: \(image)")
    }

    // MARK: Fixtures

    private static let longParagraph = Array(
        repeating: "Words of a long paragraph that wraps over many lines of the column.", count: 12
    ).joined(separator: " ")

    private static func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image {
            context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

/// Where the last paragraph sits on the page.
private struct ParagraphBox: Decodable, CustomStringConvertible {
    let width, left, right, fontSize: Double

    var description: String { "width \(width), left \(left), right \(right), text size \(fontSize)" }
}

extension ShownDocument {
    /// Where the last paragraph sits; the test fails when the page has no paragraph.
    fileprivate func paragraphBox() async throws -> ParagraphBox {
        let box = try await json(
            ParagraphBox?.self,
            """
            const paragraph = [...document.querySelectorAll("p")].at(-1);
            if (!paragraph) return null;
            const box = paragraph.getBoundingClientRect();
            return { width: box.width, left: box.left, right: innerWidth - box.right,
                     fontSize: parseFloat(getComputedStyle(paragraph).fontSize) };
            """)
        return try #require(box, "the reader renders the document's paragraphs")
    }
}
