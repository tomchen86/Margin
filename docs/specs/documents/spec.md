# Documents

## Purpose

Which files Margin opens, how they reach the reader, and how plain text is shown. The app owns the document browser; the reader is the `MarginReader` package, which shows one document in a WebView.

## Requirements

### Requirement: DOCUMENTS-1.1 Opens Markdown, HTML, and plain text

WHEN the owner opens a Markdown file (`.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`), an HTML file (`.html`, `.htm`), or a file the system counts as plain text (such as `.txt`, source code, and logs) from the document browser, the app SHALL show it in the reader.

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

### Requirement: DOCUMENTS-2.1 Other files stay closed

IF a file is neither Markdown, HTML, nor plain text, THEN the app SHALL not open it from the document browser.

#### Scenario: JSON is not plain text to the system

- **WHEN** the owner taps `Data.json` in the document browser
- **THEN** no reader opens and the document browser stays

### Requirement: DOCUMENTS-3.1 Other apps open documents in place

WHEN another app hands the app a Markdown, HTML, or plain-text file, the app SHALL open that file where it is, not a copy of it.

#### Scenario: Open in Margin from Files

- **WHEN** the owner shares `Notes.md` from the Files app to Margin
- **THEN** Margin shows `Notes.md` from its folder, and no copy of it is made

### Requirement: DOCUMENTS-4.1 Never writes

The app SHALL never write to an opened document or to any file next to it.

#### Scenario: open, read, close

- **WHEN** the owner opens `Notes.md` from a folder that also holds `Other.txt` and `images/photo.png`, then goes back to the document browser
- **THEN** the folder holds the same files, each with the same contents and modification date

### Requirement: DOCUMENTS-5.1 No file actions in the title

WHEN the owner taps the title of an open document, the app SHALL offer no way to rename, move, or duplicate the file.

#### Scenario: tapping the title

- **WHEN** the owner opens `Notes.txt` and taps its title
- **THEN** the title still names the file, and no Rename, Move, or Duplicate appears

### Requirement: DOCUMENTS-6.1 Plain text as written

WHEN the owner opens a plain-text file, the reader SHALL show its text exactly as written, in the system's monospaced font, with every space and blank line kept, long lines wrapped, and markup shown as typed.

#### Scenario: spaces and blank lines

- **WHEN** the file starts with a blank line and holds `a   b` (three spaces), two blank lines, a line indented by four spaces, and a tab
- **THEN** the reader shows each of them character for character

#### Scenario: markup

- **WHEN** the file holds `<b>bold</b> &amp; **stars**`
- **THEN** the reader shows exactly those characters, and nothing is bold

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

### Requirement: DOCUMENTS-7.1 Plain text in a readable column

WHILE the page is wider than 80 characters of plain text, the reader SHALL wrap plain text at 80 characters, in a column centered on the page.

#### Scenario: iPad in landscape

- **WHEN** a plain-text file with a 200-character line is shown on a page 1194 points wide
- **THEN** the line wraps after 80 characters, with as much space left of the column as right of it

#### Scenario: iPhone in portrait

- **WHEN** the same file is shown on a page 402 points wide
- **THEN** the line wraps at the edge of the page, before 80 characters
