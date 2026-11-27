# ADR-0004: Serve every file a page loads through `margin://`

- Date: 2026-11-27
- Status: Accepted

## Context

On iOS, opening a document from the Files app grants access to that one file. A Markdown or HTML document usually references more: `images/a.png`, `../assets/style.css`, another document. The WebView renders in a separate WebContent process, which holds none of the app's sandbox access, so loading the document as a `file:` URL leaves those references broken, and the app cannot pass its security-scoped access on to that process.

Options considered:

- `file:` URLs with read access to the document's folder: the WebContent process still cannot read outside the app's container, and folders the user grants later stay out of its reach.
- Inlining every referenced file into the page as `data:` URLs: heavy, and it breaks stylesheets, scripts, and links in HTML files that load further files themselves.
- A custom URL scheme answered in the app process.

## Decision

Every page and every file it loads come through `margin://`, answered by a scheme handler in the process that shows the page (the app, or the Quick Look extension), which holds the sandbox access.

- `margin://file/<absolute path>` serves documents and the files next to them; Markdown and HTML files become reader pages, anything else is served as is.
- `margin://app/<name>` serves the reader's bundled files (ADR-0002).
- Files are opened for reading only. Margin never writes to a document or to anything next to it.
- When the handler cannot read a file, the reader offers access to the folder that holds the document and every blocked file. Granted folders are kept as security-scoped bookmarks and reused across launches.

## Consequences

- The WebContent process needs no file access, and folders granted later work without reloading the app.
- Every frame in the WebView can request `margin://` URLs. That is why Markdown pages carry a strict policy (ADR-0002), and why a script in an HTML file, which shares the `margin://file` origin, can read files in granted folders; whether such scripts may run is decided per phase.
- The simulator does not enforce the sandbox for files outside the app, so testing the folder-access flow there needs a test hook that blocks reads the way a device would.
