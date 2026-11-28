# Links

## Purpose

What tapping a link in a document does: links to the web and to other apps leave Margin through the system, links to documents and files next to them stay in the reader with a way back, and links to headings scroll to them. The page shown is the one the commands in the `More` menu act on.

## Requirements

### Requirement: LINKS-1.1 Links that leave Margin

WHEN the owner taps a link to a web address, or to an address another app handles such as `sms:`, the app SHALL hand it to the system, which opens the default browser or that app, and the reader SHALL stay on the page.

#### Scenario: a web link

- **WHEN** the owner taps a link to `https://margin.invalid/page`
- **THEN** the default browser opens, and back in Margin the reader still shows the document

#### Scenario: another app's address

- **WHEN** the owner taps a link to `sms:5551234`
- **THEN** Messages opens

### Requirement: LINKS-2.1 Web frames stay in the page

WHEN a page loads a frame from an `https:` address, the reader SHALL load it in the page and SHALL not hand it to the browser.

#### Scenario: an embedded page

- **WHEN** the owner opens a Markdown document holding `<iframe src="https://margin.invalid/embed">`
- **THEN** the browser does not open

### Requirement: LINKS-3.1 Links to documents

WHEN the owner taps a link to a Markdown or HTML file, the reader SHALL show that file in place of the page and name it in the title, and the app SHALL offer a `Go Back` button in the toolbar that returns to the page before, shown only while there is a page to go back to.

#### Scenario: a Markdown file and back

- **WHEN** the owner opens `Notes.md`, which shows no `Go Back`, taps a link to `Other.md`, then taps `Go Back`
- **THEN** the reader shows `Other.md` with the title `Other`, then `Notes.md` again

#### Scenario: an HTML file

- **WHEN** the owner taps a link to `Page.html`, then taps `Go Back`
- **THEN** the reader shows `Page.html` with the title `Page`, then the page before

### Requirement: LINKS-4.1 Links to headings

WHEN the owner taps a link to a heading, on the same page (`#later`) or in another document (`Other.md#deep`), the reader SHALL scroll so that the heading is at the top of the page, below the toolbar.

#### Scenario: on the same page

- **WHEN** the owner taps `[Later](#later)` near the top of a long document whose heading `Later` has the id `later`
- **THEN** `Later` sits just below the toolbar

#### Scenario: in another document

- **WHEN** the owner taps `[Deep](Other.md#deep)`, and `Other.md` has the heading `Deep` far down
- **THEN** the reader shows `Other.md` with `Deep` just below the toolbar

### Requirement: LINKS-5.1 Links to other files

WHEN the owner taps a link to a file that is neither Markdown nor HTML, the reader SHALL show a text file as its text, an image, PDF, audio, or video file as WebKit shows it, and any other file as a page reading `Margin can’t show “<name>”.`, each with `Go Back`.

#### Scenario: a text file, an image, and an archive

- **WHEN** the owner taps links to `notes.txt`, `photo.png`, and `archive.zip`
- **THEN** the reader shows the text, then the image, then `Margin can’t show “archive.zip”.`

### Requirement: LINKS-6.1 Missing files

IF a linked file does not exist, THEN the reader SHALL show a page reading `Margin can’t find “<name>”.`, with `Go Back`.

#### Scenario: a link to nothing

- **WHEN** the owner taps a link to `missing.md`, which does not exist
- **THEN** the reader shows `Margin can’t find “missing.md”.`, and `Go Back` returns to the document

### Requirement: LINKS-7.1 Files out of reach

WHEN the owner taps a link to a file that iOS keeps out of the app's reach, the app SHALL offer access to a folder as LOCALFILES-2.1 describes, and once the owner grants it, the reader SHALL show the file.

#### Scenario: a document in a sibling folder

- **WHEN** `Trips/Notes/Trip.md` links to `../Days/Day 1.md`, iOS keeps it out of reach, and the owner taps the link
- **THEN** the button `Allow Access to “Trips”` appears, and once the owner grants `Trips`, the reader shows `Day 1.md`

### Requirement: LINKS-8.1 Commands act on the page shown

WHILE the reader shows a page the owner reached by a link, Share and View Source in the `More` menu SHALL act on that page's file.

#### Scenario: after following a link

- **WHEN** the owner follows a link from `Notes.md` to `Other.md`, then chooses Share, then View Source
- **THEN** the share sheet names `Other` and its size, and the source is `Other.md`'s

### Requirement: LINKS-9.1 (manual) Swiping back

WHILE the reader shows a page the owner reached by a link, a swipe from the left edge of the page SHALL go back to the page before, as `Go Back` does.

#### Scenario: on a phone

- **WHEN** the owner follows a link from `Notes.md` to `Other.md`, then swipes from the left edge
- **THEN** the reader shows `Notes.md` again, not the document browser

