# ADR-0003: Share the reader through a local Swift package

- Date: 2026-11-27
- Status: Accepted

## Context

The daily reader phase ships two targets that show documents: the app and a Quick Look Preview Extension. The proposal requires both to show a document the same way, from one reader. An extension is a separate binary with its own bundle, so whatever renders a page (page building, the `margin://` handler, the bundled markdown-it, KaTeX, and highlight.js files, folder grants, text decoding) has to reach both.

Options considered:

- The same source and resource files as members of both targets: nothing marks where the reader ends, and the two copies of the build settings drift.
- An embedded framework target in the Xcode project: one copy at run time, but its boundary lives only in project settings.
- A local Swift package in the repository.

## Decision

The reader is a local Swift package, `MarginReader`, that the app and the Quick Look extension both depend on. It holds page building, the `margin://` scheme handler, the bundled web files as package resources, folder grants, and text decoding. The app keeps the document browser and its menus; the extension keeps only its `QLPreviewingController`.

## Consequences

- The reader has one boundary that both targets use, which is also where its tests and its specs' acceptance tests point.
- Bundled files load through `Bundle.module`, not `Bundle.main`.
- The package's resource bundle is copied into both the app and the extension, so the web files (about 0.8 MB) ship twice.
- Sharing folder grants with the extension needs an App Group as well; whether that works is checked on a device before it is specified.
