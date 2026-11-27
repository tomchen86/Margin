# Margin

A minimal, native-feeling iOS app for reading Markdown and HTML files. Open a file from the Files app and read it: HTML is shown as is, Markdown is converted to HTML, both in a single WebView. Built first for its owner's daily reading, then for the App Store.

## Develop

Open `Margin.xcodeproj` in Xcode 26 and run the `Margin` scheme on an iOS 26 simulator. From the command line, name the simulator to use:

```bash
MARGIN_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" bash scripts/check.sh   # lint, format check, typecheck, tests, requirement trace
```

## Where things are

| What | Where |
|---|---|
| What the system does | `docs/specs/` |
| How the parts fit together | `docs/architecture.md` |
| Why it is built this way | `docs/adr/` |
| Where it is going | `docs/roadmap.md` |
| Plan for each phase | `docs/proposals/` |
| Plans, progress, discussion | GitHub Issues and the Project board |
| Licenses of bundled libraries | `THIRD_PARTY_NOTICES.md` |
| Rules for AI agents | `AGENTS.md` |
| Step-by-step procedures for AI agents | `skills/` |
