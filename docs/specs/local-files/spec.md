# Local files

## Purpose

How a page loads the files next to its document, such as images, through `margin://file/` (ADR-0004), and how the reader asks for access to a folder when iOS keeps a file out of reach. What a page tries to load at all is its own kind's rule: a Markdown page loads none of the document's scripts or frames (MARKDOWN-8.1), and an HTML page loads what its author wrote (HTML-1.1). Opening a document grants access to that one file; a folder the owner grants covers every file in it and its subfolders, for every document, until Margin is deleted.

## Requirements

### Requirement: LOCALFILES-1.1 Images next to the document load

WHEN a page shows an image in a file the app can read, the reader SHALL load it.

#### Scenario: beside, below, and above the document

- **WHEN** a Markdown document shows `images/photo.png`, `../assets/logo.png`, and `diagram.svg`
- **THEN** the reader shows all three images

#### Scenario: names with spaces and other scripts

- **WHEN** a Markdown document shows `<images/my photo.png>` and `圖片/相片.png`, the second written percent-encoded
- **THEN** the reader shows both images

#### Scenario: a query after the name

- **WHEN** a Markdown document shows `images/photo.png?raw=true`
- **THEN** the reader shows `images/photo.png`

### Requirement: LOCALFILES-2.1 Offer access to the folder

WHEN a page tries to load a file that iOS keeps out of the app's reach, the app SHALL show a button at the bottom of the page, not an alert, `Allow Access to “<folder>”`, naming the folder that holds the document and every such file, and tapping it SHALL open the system folder picker in that folder.

#### Scenario: an image beside the document

- **WHEN** `Notes/Trip.md` shows `images/photo.png`, and iOS keeps `images/photo.png` out of reach
- **THEN** the button reads `Allow Access to “Notes”`, and tapping it opens the folder picker in `Notes`

#### Scenario: an image in a sibling folder

- **WHEN** `Trips/Notes/Trip.md` shows `../Shared/photo.png`, and iOS keeps it out of reach
- **THEN** the button names `Trips`, which holds both the document and the image

### Requirement: LOCALFILES-3.1 Granted folders

WHEN the owner chooses a folder in the folder picker, the reader SHALL reload the page, and the app SHALL keep the grant for that folder and its subfolders across launches.

#### Scenario: grant, reload, relaunch

- **WHEN** the owner taps `Allow Access to “Notes”` and chooses `Notes`
- **THEN** the page shows the image and no longer offers access; after Margin is closed and opened again, `Trip.md` shows the image without an offer

#### Scenario: a missing image in the granted folder

- **WHEN** `Trip.md` also shows `images/missing.png`, which does not exist, and the owner has granted `Notes`
- **THEN** the image is missing, and the reader does not offer access again

#### Scenario: another document in the granted folder

- **WHEN** the owner has granted `Notes` and opens `Notes/Days/Day 1.md`, which shows `../images/photo.png`
- **THEN** the reader shows the image without an offer

### Requirement: LOCALFILES-4.1 No offer without a blocked file

WHILE nothing a page tries to load is out of the app's reach, the app SHALL not offer folder access.

#### Scenario: images the app can read

- **WHEN** the owner opens a document whose images the app can read
- **THEN** the reader shows the images, and no button offers access

#### Scenario: a document that references nothing

- **WHEN** the owner opens a document that shows no image
- **THEN** no button offers access
