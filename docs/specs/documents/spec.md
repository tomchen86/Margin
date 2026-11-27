# Documents

## Purpose

Which files Margin opens, how they reach the reader, how their bytes become text, and how their text is shown. The app owns the document browser; the reader is the `MarginReader` package, which shows one document in a WebView. A document is a file of any kind DOCUMENTS-1.1 opens.

## Requirements

### Requirement: DOCUMENTS-1.1 Opens Markdown, HTML, and text files

WHEN the owner opens a Markdown file (`.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`), an HTML file (`.html`, `.htm`), a file the system counts as JSON, YAML, or XML (such as `.json`, `.yaml`, `.yml`, and `.xml`, and formats built on them, such as `.svg`, `.xhtml`, `.rss`, and `.geojson`), or a file the system counts as plain text (such as `.txt`, source code, and logs) from the document browser, the app SHALL show it in the reader.

#### Scenario: every Markdown extension

- **WHEN** the owner opens `Notes.md`, `Notes.markdown`, `Notes.mdown`, `Notes.mkd`, or `Notes.mkdn`
- **THEN** the reader shows the words in the file

#### Scenario: extension in capitals

- **WHEN** the owner opens `README.MD`
- **THEN** the reader shows the words in the file

#### Scenario: HTML

- **WHEN** the owner opens `Page.html` or `Page.htm`
- **THEN** the reader shows the words in its body

#### Scenario: plain text, source code, and logs

- **WHEN** the owner opens `Notes.txt`, `Main.swift`, or `Build.log`
- **THEN** the reader shows the words in the file

#### Scenario: JSON, YAML, and XML

- **WHEN** the owner opens `Data.json`, `Config.yaml`, `Config.yml`, or `Feed.xml`
- **THEN** the reader shows the words in the file

#### Scenario: formats built on XML and JSON

- **WHEN** the owner opens `Logo.svg` or `Map.geojson`
- **THEN** the reader shows the words in the file

### Requirement: DOCUMENTS-2.1 Other files stay closed

IF a file is of no kind DOCUMENTS-1.1 names, THEN the app SHALL not open it from the document browser.

#### Scenario: TOML and INI

- **WHEN** the owner taps `Settings.toml`, `Setup.ini`, or `Letter.rtf` in the document browser
- **THEN** the browser shows the file as unavailable, no reader opens, and the document browser stays

### Requirement: DOCUMENTS-3.1 Declared as an in-place viewer

The app SHALL declare to iOS that it views every kind of document DOCUMENTS-1.1 names and opens documents in place, so that other apps can hand it such a file without a copy being made.

#### Scenario: what iOS is told

- **WHEN** iOS reads the app's declarations
- **THEN** they name Markdown (`net.daringfireball.markdown`), HTML (`public.html`), JSON (`public.json`), YAML (`public.yaml`), XML (`public.xml`), and plain text (`public.plain-text`) with the Viewer role, and say that documents open in place

### Requirement: DOCUMENTS-4.1 Never writes

The app SHALL never write to an opened document or to any file next to it, other than through a file action the owner chooses in the system's document browser.

#### Scenario: open, read, close

- **WHEN** the owner opens `Notes.md` from a folder that also holds `Other.txt` and `images/photo.png`, then goes back to the document browser
- **THEN** the folder holds the same files, each with the same contents and modification date

### Requirement: DOCUMENTS-5.1 No file actions in the title

WHEN the owner taps the title of an open document, the app SHALL offer no way to rename, move, or duplicate the file.

#### Scenario: tapping the title

- **WHEN** the owner opens `Notes.txt` and taps its title
- **THEN** the title still names the file, and no Rename, Move, or Duplicate appears

### Requirement: DOCUMENTS-6.1 Text as written

WHEN the owner opens a document, the reader SHALL show its text exactly as written, in the system's monospaced font, with every space and blank line kept, long lines wrapped, and markup shown as typed.

#### Scenario: spaces and blank lines

- **WHEN** the file starts with a blank line and holds `a   b` (three spaces), two blank lines, a line indented by four spaces, and a tab
- **THEN** the reader shows each of them character for character

#### Scenario: markup

- **WHEN** the file holds `<b>bold</b> &amp; **stars**`
- **THEN** the reader shows exactly those characters, and nothing is bold

#### Scenario: Markdown and HTML

- **WHEN** `Notes.md` holds `# Title` and `*stars*`, and `Page.html` holds `<h1>Title</h1>` and a `<script>`
- **THEN** the reader shows each file's text character for character, nothing is bold or italic, and the script does not run

#### Scenario: JSON, YAML, and XML

- **WHEN** `Data.json`, `Config.yaml`, and `Feed.xml` hold indented data, `Feed.xml` starts with `<?xml version="1.0"?>`, and `Logo.svg` draws a circle
- **THEN** the reader shows each file's text character for character, not as a tree, an image, or with its markup hidden

#### Scenario: source code

- **WHEN** `Generic.swift` holds `func first<T: Equatable>(_ items: [T]) -> T?`
- **THEN** the reader shows the line exactly as written

#### Scenario: monospaced

- **WHEN** the file holds a line of ten `i` and a line of ten `M`
- **THEN** both lines are the same width, in the system's monospaced font

#### Scenario: long lines

- **WHEN** the file holds a long line that includes a 200-character word without spaces
- **THEN** the line wraps within the page, and the page does not scroll sideways

#### Scenario: empty file

- **WHEN** the file is empty
- **THEN** the reader shows an empty page, with no error

### Requirement: DOCUMENTS-7.1 Text in a readable column

WHILE the page is wider than 80 characters of text, the reader SHALL wrap a document's text at 80 characters, in a column centered on the page.

#### Scenario: iPad in landscape

- **WHEN** `Wide.txt`, `Wide.md`, or `Wide.html`, each holding a 200-character line, is shown on a page 1194 points wide
- **THEN** the line wraps after 80 characters, with as much space left of the column as right of it

#### Scenario: iPhone in portrait

- **WHEN** the same files are shown on a page 402 points wide
- **THEN** the line wraps within one character of the page's right margin, before 80 characters, and neither margin is wider than 24 points

### Requirement: DOCUMENTS-8.1 UTF-8 first

WHEN a document without a byte-order mark is valid UTF-8, the reader SHALL decode it as UTF-8.

#### Scenario: Chinese in UTF-8

- **WHEN** a UTF-8 file holds `中文筆記 and café`
- **THEN** the reader shows `中文筆記 and café`

### Requirement: DOCUMENTS-9.1 Big5, GB18030, and Shift-JIS

WHEN a document without a byte-order mark is not valid UTF-8, and Big5, GB18030, or Shift-JIS decodes it without loss, the reader SHALL decode it as the one of those three that the system's detector picks, or, when the detector picks none, as the first of Big5, GB18030, and Shift-JIS that decodes it without loss.

#### Scenario: old notes in each encoding

- **WHEN** a file holds Traditional Chinese in Big5, Simplified Chinese in GB18030, or Japanese in Shift-JIS, though other encodings of the three also decode it
- **THEN** the reader shows the text as written

#### Scenario: a few characters

- **WHEN** a file holds only `天氣` in Big5, or only `中文` in GB18030
- **THEN** the reader shows `天氣` or `中文`

#### Scenario: a Markdown note in Big5

- **WHEN** `筆記.md` is Big5 and holds Traditional Chinese
- **THEN** the reader shows its text

### Requirement: DOCUMENTS-10.1 Byte-order marks

WHEN a document starts with a UTF-8, UTF-16, or UTF-32 byte-order mark, the reader SHALL decode it in that encoding and byte order, and SHALL not show the mark.

#### Scenario: each mark

- **WHEN** files hold `中文 notes` after a UTF-8 mark, a UTF-16 mark in either byte order, or a UTF-32 mark in either byte order
- **THEN** the reader shows `中文 notes` for each, with nothing before it

### Requirement: DOCUMENTS-11.1 Nothing fits

IF a document has no byte-order mark, is not valid UTF-8, and none of Big5, GB18030, and Shift-JIS decodes it without loss, THEN the reader SHALL show it as UTF-8 with a replacement mark (`�`) where its bytes are not UTF-8, and no error.

#### Scenario: Windows-1252

- **WHEN** a file holds `Café au lait` in Windows-1252
- **THEN** the reader shows `Caf� au lait`
