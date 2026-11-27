# Proposal: Daily reader

- Date: 2026-11-27
- Status: Accepted

Merging this file accepts it as a whole: everything outside "Open questions" is decided. Order and timing live in `docs/roadmap.md`, not here.

## Summary

The first Margin its owner reads with every day, on their own iPhone and iPad: open a Markdown, HTML, or text file and read it.

- **Opening**: the system document browser (`DocumentGroup`), read-only. Recent files, iCloud Drive, and other file providers come from the system.
- **Markdown**: CommonMark with tables, strikethrough, task lists, autolinks, and footnotes; `$…$` and `$$…$$` math; highlighted code blocks; an anchor on every heading. The page converts it with markdown-it (ADR-0002).
- **Table of contents**, built from the headings.
- **HTML**: shown as written, with its own stylesheets, images, and scripts.
- **Web content** in a document (images, media, `https:` iframes) loads as it would in a browser.
- **Files next to the document** (images, stylesheets, linked documents) load through Margin's `margin://` scheme. When the sandbox blocks one, the reader offers to grant access to the folder that holds the document and the missing files, and remembers the grant.
- **Links**: web links open in Safari; links to other Markdown or HTML files open in Margin.
- **Reading**: the system font with Dynamic Type, light and dark mode, find in page, a source view, and the share sheet.
- **Text encodings**: besides UTF-8, Big5, GB18030, and Shift-JIS are detected.
- **Platform**: iOS and iPadOS 26 and later, since the reader uses SwiftUI's `WebView`.

A local prototype, outside this repo, already does all of this except the table of contents, on the simulator. This phase builds it again in this repo, issue by issue, with specs and acceptance tests; the prototype is a reference for the spec author and the implementer, not code to copy without review. The Xcode project, swift-format, Swift Testing, and a macOS CI runner arrive with the first issue.

## Motivation

The owner keeps notes and documents as Markdown and HTML files, with images in nearby folders, code, and math, and wants to read them on iPhone and iPad the way a native app would show them. Margin is for the owner first; the App Store comes after the owner relies on it.

## Validation question

Has the owner read their own documents in Margin on a physical iPhone every day for two weeks without switching to another app because Margin showed something wrong or could not open it?

## Principles

- Margin never writes to a document or to anything next to it.
- Every file a page loads goes through `margin://` and is read by the app, which holds the sandbox access. The WebView's process needs none.
- Margin asks for folder access only when a page is missing a file.
- Markdown pages run only the app's bundled scripts (ADR-0002).
- Keeping the user's files out of reach of what a document runs is Margin's job. What a document's own web content tells its servers is treated as a browser treats it.
- Margin itself needs no network: its libraries and fonts are bundled. The only network traffic is what a document references, such as a web image or an embedded page.
- The system's own components and look come first (document browser, menus, find, share sheet, system colors and fonts). Custom interface only where the system has none.

## Not doing

- **App Store release**: name check, icon, license notices screen, privacy policy, and localization belong to the next phase, after the owner relies on the app.
- **Diagrams (Mermaid and similar)**: not in the goal. ADR-0002's in-page rendering leaves room to add them later.
- **Managing or syncing files**: the Files app and its providers do that.
- **A switch to block web content**: added only if the owner needs it.

## Open questions

- **Table of contents**: a sheet from the toolbar, an iPad sidebar, or both. Depends on how long the owner's documents are and whether the owner reads them on iPad.
- **Scripts in HTML files**: today they run, and a script in an HTML file can read any file in a granted folder through `margin://` and send it to the web. Keep them on, turn them off by default, or limit them with a policy like Markdown pages have. Depends on whether the owner opens HTML from sources they do not trust; the App Store phase has to settle it either way.
- **Installing on the owner's devices**: from Xcode with a free Apple account, where the app stops opening after 7 days, or through TestFlight, which needs the paid Apple Developer Program. Depends on whether the owner joins the program now.
- **First document after launch**: on the simulator it stays blank for 1 to 2 seconds while WebKit starts, then later documents open at once. Whether this needs a fix, such as starting the WebView at launch, depends on how long it takes on a physical iPhone.
