# Roadmap

What we are building toward, and in what order. One line per phase: why it sits where it does, plus links to its proposal and, once it starts, its milestone. Details live in `docs/proposals/`; progress and dates live in GitHub milestones. This file changes only when the direction changes.

## Goal

Reading a Markdown or HTML file on an iPhone or iPad should feel like reading it in a native app: open it from the Files app, see it rendered, in light or dark mode, with links handed to Safari. Margin does that with one WebView and as little chrome as possible. It is for its owner first, as a daily reader of notes and documents with images, code, math, and a table of contents; then for anyone on the App Store who wants the same.

## Now

- **<Phase>**: <why now>. Milestone: <link>. Proposal: <link>

## Next

- **<Phase>**: <why next>. Proposal: <link, once it has one>

## Later

- **<Phase>**: <why later, or what has to be true first>. Proposal: <link, once it has one>

## Not doing

- **Editing files**: Margin is a viewer. Editing would need a second interface and a save path that can lose data.
- **Native Markdown rendering (`AttributedString(markdown:)`)**: it drops most of what documents use, such as tables, code highlighting, and math. Markdown becomes HTML in the WebView instead.
