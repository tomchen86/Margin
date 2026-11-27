# Roadmap

What we are building toward, and in what order. One line per phase: why it sits where it does, plus links to its proposal and, once it starts, its milestone. Details live in `docs/proposals/`; progress and dates live in GitHub milestones. This file changes only when the direction changes.

## Goal

Reading a Markdown or HTML file on an iPhone or iPad should feel like reading it in a native app: open it from the Files app, see it rendered, in light or dark mode, with links handed to Safari. Margin does that with one WebView and as little chrome as possible. It is for its owner first, as a daily reader of notes and documents with images, code, math, and a table of contents; then for anyone on the App Store who wants the same.

## Now

## Next

- **Daily reader**: Margin is for its owner first, so the first phase is the reader the owner uses every day; the App Store builds on it. Proposal: [2026-11-27-daily-reader](proposals/2026-11-27-daily-reader.md)

## Later

- **App Store release**: once the owner relies on the daily reader. Name check, icon, license notices, privacy policy, localization, and whether scripts in HTML files may run.

## Not doing

- **Editing files**: Margin is a viewer. Editing would need a second interface and a save path that can lose data.
- **Converting Markdown with `AttributedString(markdown:)`**: its parser reads `*`, `_`, and `\` inside formulas as Markdown, so math is broken before a math renderer sees it. markdown-it converts Markdown in the WebView instead (ADR-0002).
