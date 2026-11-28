# Markdown

## Purpose

How the reader shows a Markdown document: converted to HTML in the page by the bundled markdown-it (ADR-0002), with GitHub's tables, strikethrough, task lists, bare links, and footnotes, under a policy that lets only the app's own scripts run. A Markdown document is a file DOCUMENTS-1.1 opens as Markdown.

## Requirements

### Requirement: MARKDOWN-1.1 CommonMark

WHEN the owner opens a Markdown document, the reader SHALL show it rendered as CommonMark: headings, paragraphs, emphasis, links, images, lists, block quotes, code, thematic breaks, line breaks, and HTML.

#### Scenario: blocks and emphasis

- **WHEN** the document holds `# Title`, `## Part`, `*emphasis*`, `**strong**`, `` `code` ``, a link, an image, a bulleted list, a list starting at `3.`, a block quote, a fenced and an indented code block, and `***`
- **THEN** the reader shows two levels of heading, emphasis and strong text, inline code, the link and the image, both lists (the second numbered from 3), the quote, both code blocks, and a rule

#### Scenario: line breaks

- **WHEN** one paragraph's lines are separated by a single newline, and another's lines end in two spaces or a backslash
- **THEN** the single newline shows as a space, and the two spaces or the backslash start a new line

#### Scenario: punctuation as typed

- **WHEN** the document holds `"double" 'single' -- ... (c)`
- **THEN** the reader shows exactly those characters: no curly quotes, dashes, ellipsis, or ©

#### Scenario: escapes and entities

- **WHEN** the document holds `\*not emphasis\* &copy; &amp;`
- **THEN** the reader shows `*not emphasis* © &`, with no emphasis

#### Scenario: HTML

- **WHEN** the document holds `<kbd>⌘K</kbd>`, a `<details>` with a `<summary>`, and `<span style="color: rgb(255, 0, 0)">red</span>`
- **THEN** the reader shows a keyboard key, a closed disclosure, and red text

### Requirement: MARKDOWN-2.1 Tables

WHEN a Markdown document contains a GitHub table, the reader SHALL show it as a table with a header row, each column aligned as its delimiter row says.

#### Scenario: alignment, pipes, and short rows

- **WHEN** a table's delimiter row is `|:--|:-:|--:|`, a cell holds `**b**` or `c \| d`, and a row has one cell
- **THEN** the columns align left, center, and right; the cells show bold `b` and `c | d`; and the short row gets empty cells

### Requirement: MARKDOWN-3.1 Strikethrough

WHEN text in a Markdown document is wrapped in two tildes on each side, the reader SHALL show it struck through, and SHALL show single tildes as typed.

#### Scenario: two tildes and one

- **WHEN** the document holds `~~gone~~ and ~one~, about ~5 min`
- **THEN** only `gone` is struck through, and `~one~, about ~5 min` shows as typed

### Requirement: MARKDOWN-4.1 Task lists

WHEN a list item in a Markdown document starts with `[ ]`, `[x]`, or `[X]` and a space, the reader SHALL show a disabled checkbox in place of those characters, checked for `x` or `X`.

#### Scenario: open and done

- **WHEN** a bulleted list holds `[ ] open`, `[x] done`, and `[X] also done`, and a numbered list holds `[ ] numbered`
- **THEN** the reader shows four checkboxes, the second and third checked, followed by the items' text, and tapping one changes nothing

#### Scenario: not a task

- **WHEN** list items hold `not [ ] a task` and `[ ]no space`
- **THEN** the reader shows them as typed, without a checkbox

### Requirement: MARKDOWN-5.1 Links in bare text

WHEN bare text in a Markdown document starts with `https://`, `http://`, or `www.`, or is an e-mail address, the reader SHALL show it as a link, and SHALL show bare domains and file names as typed.

#### Scenario: what becomes a link

- **WHEN** the document holds `https://example.com/a?b=1,`, `www.example.com`, `<https://example.org/x>`, `someone@example.com`, and `(see https://example.net/p)`
- **THEN** each is a link: `www.example.com` to `http://www.example.com`, the e-mail address to `mailto:someone@example.com`, and the comma and the parenthesis outside the links

#### Scenario: what stays text

- **WHEN** the document holds `example.com`, `README.md`, and `` `https://code.example.com` ``
- **THEN** none of them is a link

### Requirement: MARKDOWN-6.1 Footnotes

WHEN a Markdown document has a footnote reference `[^label]` and a definition `[^label]: text`, the reader SHALL show the reference as a superscript number that links to the note, and SHALL list the notes after the rest of the document, numbered in the order they are first referenced, each with a link back to its reference.

#### Scenario: numbered and named notes

- **WHEN** the text references `[^1]`, then `[^note]`, then `[^1]` again, and the definitions list `[^note]` before `[^1]`
- **THEN** the references show 1, 2, and 1; the notes at the end list the `[^1]` note first; and each note links back to a reference

#### Scenario: a reference without a note

- **WHEN** the text holds `[^nope]` and no `[^nope]:` definition
- **THEN** the reader shows `[^nope]` as typed

### Requirement: MARKDOWN-7.1 Front matter

WHEN a Markdown document's first line is `---` and a later line is `---`, the reader SHALL show the lines between them, as typed, in a monospaced block at the top, and render the rest of the document as Markdown.

#### Scenario: YAML front matter

- **WHEN** the document starts with `---`, `title: Notes`, `tags: [a, b]`, `---`, then `# Heading`
- **THEN** the reader shows `title: Notes` and `tags: [a, b]` in a monospaced block at the top, no `---`, and `Heading` as a heading

#### Scenario: no closing line

- **WHEN** the document's first line is `---` and no later line is `---`
- **THEN** the first line shows as a rule, as in CommonMark

### Requirement: MARKDOWN-8.1 Only the app's scripts run

IF a Markdown document contains a script, an event handler, a `javascript:` link, an embedded object, or a frame that is not `https:`, THEN the reader SHALL neither run nor load it.

#### Scenario: scripts and handlers

- **WHEN** the document holds an inline `<script>`, `<script src="evil.js">` with `evil.js` next to it, `onerror`, `ontoggle`, and `onload` handlers, and a `javascript:` link that the owner taps
- **THEN** none of them runs

#### Scenario: frames and objects

- **WHEN** the document holds a `srcdoc` frame, a frame of `Other.md` next to it, an `http:` frame, a `data:` frame, an `<object>`, and an `<embed>`
- **THEN** none of them loads

### Requirement: MARKDOWN-9.1 Web content loads

WHEN a Markdown document references images or media on the web, over `https:` or `http:`, an image embedded as a `data:` URL, or a frame from `https:`, the reader SHALL load them as a browser would.

#### Scenario: images, media, and frames

- **WHEN** the document holds `https:` and `http:` images, `https:` video, `http:` audio, an `https:` frame, and a `data:` image
- **THEN** the page lets each of them load, the `data:` image shows, and the app allows `http:` loads for web content only

### Requirement: MARKDOWN-10.1 Nothing from the network for itself

The reader SHALL load a Markdown page's own scripts, styles, and fonts from the app, never from the network.

#### Scenario: a document without web content

- **WHEN** the owner opens `# Title` and a paragraph
- **THEN** the page's scripts and stylesheets come from the app, and the page cannot load a script, a stylesheet, a font, or data from the web

### Requirement: MARKDOWN-11.1 Readable column

WHILE the page is wider than 42 times the size of its body text, the reader SHALL show a Markdown document in a column that wide, centered on the page.

#### Scenario: iPad in landscape

- **WHEN** a long paragraph is shown on a page 1194 points wide
- **THEN** the paragraph is 42 times its text size wide, with as much space left of it as right of it

#### Scenario: iPhone in portrait

- **WHEN** the same paragraph is shown on a page 402 points wide
- **THEN** it spans the page apart from margins of at most 24 points

### Requirement: MARKDOWN-12.1 Wide content

WHEN a table or a code block in a Markdown document is wider than the column, the reader SHALL let it scroll sideways inside itself while the page does not, and SHALL wrap long words and links in paragraphs.

#### Scenario: a wide table, a long code line, a long link

- **WHEN** the document holds a 20-column table, a code block with a 300-character line, and a paragraph with a 200-character link and a 200-character word
- **THEN** the table and the code block each scroll sideways, the paragraph wraps within the page, and the page does not scroll sideways

### Requirement: MARKDOWN-13.1 Images fit the column

WHEN a Markdown document shows an image wider than the column, the reader SHALL shrink it to the column's width, keeping its proportions.

#### Scenario: a 2000-point-wide image

- **WHEN** the document shows a 2000 × 100 image on a page 402 points wide
- **THEN** the image is as wide as the column and a twentieth as tall

### Requirement: MARKDOWN-14.2 The document's own styles

WHEN a Markdown document contains a `<style>` element or a `style` attribute, the reader SHALL apply it, and SHALL load no stylesheet, neither from the web nor from a file next to the document.

#### Scenario: a style element, an attribute, and a web stylesheet

- **WHEN** the document holds `<style>.note { color: green } table { font-size: 12px }</style>`, a paragraph of class `note`, a table, `<span style="color: red">`, and `<link rel="stylesheet" href="https://…">`
- **THEN** the note is green, the table's text is 12 points, the span is red, and the web stylesheet does not load

#### Scenario: a stylesheet next to the document

- **WHEN** the document holds `<link rel="stylesheet" href="style.css">`, and `style.css` next to it colors a paragraph blue
- **THEN** the paragraph is not blue: the stylesheet does not load

### Requirement: MARKDOWN-15.1 The reader stays on the document

IF a Markdown document contains a `<meta>` or `<base>` element, THEN the reader SHALL ignore it: a refresh does not move the reader off the document, and the document's links and images resolve against the document's own location.

#### Scenario: a refresh and a base address

- **WHEN** the document holds `<meta http-equiv="refresh" content="0; url=?moved">`, `<base href="https://margin.invalid/">`, and `![photo](images/photo.png)`
- **THEN** the reader stays on the document, and the image resolves to `images/photo.png` next to the document

### Requirement: MARKDOWN-17.1 Math

WHEN a Markdown document contains a formula between `$` and `$`, or between `$$` and `$$`, the reader SHALL typeset it with KaTeX and the app's own math fonts: inline for `$…$`, and as a display formula on its own line for `$$…$$`, inside a sentence too, with Markdown leaving the formula's characters as typed.

#### Scenario: inline and display

- **WHEN** a paragraph holds `$a*b*c$` and `$\{x\}$`, and a block holds `$$\sum_{i=1}^n i$$`
- **THEN** both inline formulas and the display formula are typeset, the `*` and `\{` reach the formulas as typed, and nothing is in emphasis

#### Scenario: display math inside a sentence

- **WHEN** a sentence reads `The area is $$\pi r^2$$ for a circle.`
- **THEN** the formula is typeset as display math on a line of its own

### Requirement: MARKDOWN-18.1 Invalid formulas

IF a formula is invalid, THEN the reader SHALL show that formula's source in red, where the formula stands, and typeset the rest of the page.

#### Scenario: an unclosed brace

- **WHEN** a paragraph holds `$\frac{a$`, then `$x^2$`, then `after`
- **THEN** `\frac{a` shows in red, `$x^2$` is typeset, and `after` follows

### Requirement: MARKDOWN-19.1 Dollars as text

WHEN an opening `$` is followed by a space, a closing `$` follows a space or comes before a digit, a `$` is escaped as `\$`, or the dollars are in code, the reader SHALL show the dollar signs as text, not a formula, and SHALL treat `\(…\)` and `\[…\]` as Markdown text.

#### Scenario: prices and escapes

- **WHEN** a document holds `$5 and $10`, `$ x$`, `$x $`, `\$x\$`, `` `$y$` ``, `\(z\)`, and `$x^2$`
- **THEN** it shows `$5 and $10`, `$ x$`, `$x $`, `$x$`, `$y$` in code, and `(z)` as text, and typesets only `$x^2$`

### Requirement: MARKDOWN-20.1 Wide formulas

WHEN a display formula is wider than the column, the reader SHALL let it scroll sideways inside itself while the page does not.

#### Scenario: a long sum

- **WHEN** a display formula adds sixty terms
- **THEN** the formula scrolls sideways, and the page does not

