# HTML

## Purpose

How the reader shows an HTML document: as its author wrote it, with its own styles, scripts, and images, the way a browser would show the file. An HTML document is a file DOCUMENTS-1.1 opens as HTML.

## Requirements

### Requirement: HTML-1.1 As its author wrote it

WHEN the owner opens an HTML document, the reader SHALL show it as written, with its own stylesheets, scripts, and images, whether inline, in files next to it, or on the web, and with no styles or scripts of the reader's own.

#### Scenario: inline styles and scripts

- **WHEN** the document's `<style>` colors a paragraph and its inline `<script>` adds a paragraph
- **THEN** the reader shows the colored paragraph and the added one

#### Scenario: files next to the document

- **WHEN** the document links `style.css`, runs `app.js`, shows `images/photo.png`, and its script reads `data.json`, all next to it
- **THEN** the style applies, the script runs, the image shows, and the data appears on the page

#### Scenario: nothing of the reader's own

- **WHEN** the document is a single unstyled paragraph
- **THEN** the page holds no stylesheet or script from the app

#### Scenario: the web

- **WHEN** the page adds a script, a stylesheet, an image, and frames from `https:` and `http:` addresses
- **THEN** the reader lets each of them load, as a browser would

### Requirement: HTML-2.1 The device's width

WHEN an HTML document has no viewport tag, the reader SHALL lay it out as wide as the screen it is shown on, unzoomed, and SHALL otherwise follow the document's own viewport tag.

#### Scenario: no viewport tag

- **WHEN** a document without a viewport tag is shown on a page 402 points wide
- **THEN** it is laid out 402 points wide, not at a desktop width

#### Scenario: the document's own viewport tag

- **WHEN** a document holds `<meta name="viewport" content="width=600">`
- **THEN** it is laid out 600 points wide

### Requirement: HTML-3.1 Its own colors

WHILE the system is in dark mode, the reader SHALL show an HTML document in its own colors: light where the document sets nothing, and dark where its own styles follow `prefers-color-scheme`.

#### Scenario: no dark styles

- **WHEN** an unstyled document is shown in dark mode
- **THEN** its text is black, as on a light page

#### Scenario: its own dark styles

- **WHEN** a document whose `@media (prefers-color-scheme: dark)` rule colors its text is shown in dark mode
- **THEN** its text takes that color

### Requirement: HTML-4.1 Its own text sizes

The reader SHALL show an HTML document's text at the sizes the document sets, and at the browser's default size where it sets none, never at a size of the reader's own.

#### Scenario: unstyled and set sizes

- **WHEN** a document holds an unstyled paragraph and a paragraph set to `20px`
- **THEN** they are 16 and 20 pixels, though the system's body text is another size

### Requirement: HTML-5.1 No dialogs

WHEN an HTML document's script calls `alert`, `confirm`, or `prompt`, the reader SHALL show nothing and let the script go on, as if the owner had dismissed it: `confirm` returns false and `prompt` returns null.

#### Scenario: all three

- **WHEN** a script calls `alert`, then `confirm`, then `prompt`, and writes down what they returned
- **THEN** no dialog appears, and the script writes `false` and `null`

### Requirement: HTML-6.1 Its own charset

WHEN an HTML document without a byte-order mark declares its charset, with `<meta charset>` or a `<meta http-equiv="Content-Type">`, the reader SHALL decode it in that charset rather than detect one, as a browser does.

#### Scenario: declared charsets

- **WHEN** a document declares `windows-1252` and holds `Café`, declares `iso-8859-1` through `http-equiv` and holds `Crème brûlée`, or declares `shift_jis` and holds Japanese
- **THEN** the reader shows each text as written

#### Scenario: the declaration wins

- **WHEN** a document declares `utf-8` but its bytes are Big5
- **THEN** the reader decodes it as UTF-8, with replacement marks, not as Big5
