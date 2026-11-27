# Roadmap

What we are building toward, and in what order. One line per phase: why it sits where it does, plus links to its proposal and, once it starts, its milestone. Details live in `docs/proposals/`; progress and dates live in GitHub milestones. This file changes only when the direction changes.

## Goal

Reading a Markdown or HTML file on an iPhone or iPad should feel like reading it in a native app: open it from the Files app, see it rendered, in light or dark mode, with links handed to Safari. Margin does that with one WebView and as little chrome as possible. It is for its owner first, as a daily reader of notes and documents with images, code, math, and a table of contents; then for anyone on the App Store who wants the same.

## Now

- **Daily reader**: Margin is for its owner first, so the first phase is the reader the owner uses every day, together with its Quick Look preview, the owner's top priority, which shares the same reader. Every later phase builds on it. Milestone: [Daily reader](https://github.com/tomchen86/Margin/milestone/1). Proposal: [2026-11-27-daily-reader](proposals/2026-11-27-daily-reader.md)

## Next

## Later

- **iPad multiple windows**: several documents side by side, each window reopening its own document. After the reader works well in one window.
- **Share sheet extension**: open Markdown or HTML that another app shares as text or an attachment. Files already hands documents to Margin without it.
- **Themes**: reading settings beyond the system look, such as typeface, text width, and color themes. After the default look has been used for a while.
- **iCloud**: Margin's own folder in iCloud Drive, and settings that follow the owner across devices. Reading from iCloud Drive already works through the system document browser.
- **App Store release**: once the owner relies on the daily reader and the phases above are in. Name check, icon, license notices, privacy policy, localization, and whether scripts in HTML files may run.
- **Source editing**: the source view becomes editable in the system's native text view, with the reader as its preview, switched on iPhone and side by side on iPad. `DocumentGroup` handles saving, file coordination, and iCloud versions. Last, because it ends the promise that Margin never writes to a file, so the reader proves itself first.

## Not doing

- **WYSIWYG editing, or a code editor inside the WebView**: several times the work of a native source editor, and less native on iPhone.
- **Converting Markdown with `AttributedString(markdown:)`**: its parser reads `*`, `_`, and `\` inside formulas as Markdown, so math is broken before a math renderer sees it. markdown-it converts Markdown in the WebView instead (ADR-0002).
