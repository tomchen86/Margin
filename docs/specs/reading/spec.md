# Reading

## Purpose

How the reader's own pages read like system text: the system font at the owner's text size, in light and dark mode. The reader's own pages are those of Markdown documents and of documents shown as their text. An HTML document keeps its own fonts, sizes, and colors (HTML-3.1, HTML-4.1).

## Requirements

### Requirement: READING-1.1 System font

The reader SHALL show a Markdown document's text in the system font.

#### Scenario: paragraphs, headings, and lists

- **WHEN** the owner opens a Markdown document with a heading, a paragraph, and a list
- **THEN** each is in the system font

### Requirement: READING-2.1 The owner's text size

The reader SHALL size the text of Markdown documents and of documents shown as their text by the owner's text size, with body text at the system's body size for that setting.

#### Scenario: the default size

- **WHEN** the owner's text size is the default
- **THEN** a Markdown paragraph and a plain-text file's text are at the system's body size, 17 points

#### Scenario: the largest size

- **WHEN** the owner's text size is the largest accessibility size
- **THEN** a Markdown paragraph and a plain-text file's text are more than twice as tall as at the default size

### Requirement: READING-3.1 (manual) A text size change at once

WHEN the owner changes the text size while a document is open, the reader SHALL show the document at the new size at once, without reopening it.

#### Scenario: from Control Center

- **WHEN** the owner raises the text size in Control Center while reading a Markdown document
- **THEN** the page's text grows as soon as Control Center closes

### Requirement: READING-4.1 Light and dark

The reader SHALL show Markdown documents and documents shown as their text with dark text on a light background in light mode, and light text on a dark background in dark mode, switching at once when the mode changes.

#### Scenario: each mode

- **WHEN** a Markdown document and a plain-text file are shown in light mode, then in dark mode
- **THEN** each has dark text on a light background, then light text on a dark background

#### Scenario: switching while open

- **WHEN** the mode changes from light to dark while a document is shown
- **THEN** the page turns dark without reopening
