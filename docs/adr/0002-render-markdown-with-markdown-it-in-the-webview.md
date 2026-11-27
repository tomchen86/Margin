# ADR-0002: Render Markdown with markdown-it in the WebView

- Date: 2026-11-27
- Status: Accepted

## Context

Margin shows every document in one WebView, so Markdown has to become HTML somewhere. The roadmap's goal asks for documents with images, highlighted code, math, and a table of contents.

A prototype, kept on this repo's `prototype` branch, first converted Markdown with Foundation's `AttributedString(markdown:)`, turning its presentation intents into HTML. That handled CommonMark, tables, and task lists, but math cannot be added on top of it. The parser reads `*`, `_`, and `\` inside `$…$` as Markdown before any math renderer sees the formula: `$a*b*c$` comes out with an emphasized `b`, and `\{` loses its backslash. Math has to be recognized while parsing.

Options considered:

- Foundation's parser with post-processing: cannot repair math, as above.
- cmark-gfm in Swift (for example swift-markdown): adds footnotes, but math and highlighting would still need JavaScript libraries, so the app would carry a Swift parser and JavaScript renderers side by side.
- markdown-it, KaTeX, and highlight.js in JavaScriptCore in the app process, handing finished HTML to the WebView: pages would need no JavaScript, but JavaScriptCore in an iOS app runs without a JIT, so long documents render slowly, and libraries that need a DOM, such as Mermaid, cannot run at all.
- The same libraries in the reader page itself.

## Decision

The reader page converts Markdown with markdown-it, markdown-it-footnote, KaTeX for `$…$` and `$$…$$`, and highlight.js for fenced code blocks. Math, task lists, and heading anchors are small rules of our own, not extra packages.

- The libraries, KaTeX's fonts, and the highlight.js themes are bundled in the app at pinned versions and served from `margin://app/`. Nothing is fetched from the network.
- The Markdown source is embedded in the page as a JSON string, and a bundled script renders it.
- Markdown pages carry a Content Security Policy that lets only scripts from `margin://app/` run: `default-src 'none'`, no inline scripts or event handlers, no `connect-src`, and frames only from `https:`. Scripts and event handlers inside a document never run, local and inline frames are blocked, and no script can read files with `fetch`.
- Web content in a document loads as it would in a browser: images and media from the web, and iframes from `https:`. Margin is responsible for keeping the user's files out of reach; what a document's own web content tells its servers is left to the document, as browsers and other Markdown readers do.
- HTML files are not converted and get no such policy: they are shown as written, with their own scripts.

## Consequences

- Math, highlighting, footnotes, and heading anchors come from maintained libraries instead of a parser of our own.
- The prototype checked this on the iOS 26.5 simulator on 2026-11-27. An 89 KB document with 640 formulas and 50 highlighted code blocks finished rendering about 150 ms after navigation started. A test document's scripts, event handlers, `srcdoc` and local-file iframes, `javascript:` link, script elements added through the DOM, and `fetch` of a neighboring file were all blocked, while an `https:` iframe loaded. Speed on a physical device is not measured.
- Markdown pages need JavaScript enabled in the WebView, so the policy is what keeps a document's content from running code. Loosening it, for example with `'unsafe-inline'` scripts, a `connect-src`, or frames from `margin:`, reopens that.
- Raw HTML in Markdown still renders, minus what the policy blocks: scripts, event handlers, embedded objects, and frames that are not `https:`.
- A web frame has its own origin, so the same-origin policy keeps it from reading `margin://` responses; the prototype did not test this directly. A web frame can still request `margin://` paths, so it can learn whether a file exists and can make the reader offer folder access.
- The app grows by about 0.8 MB. Library updates are manual: replace the files, then test again. The libraries' licenses (MIT, BSD-3-Clause) require the app to ship their notices.
- Acceptance tests for Markdown go through `WebPage`: load a document, then query the page with JavaScript. They are slower than comparing strings, and they check what the reader actually shows.
