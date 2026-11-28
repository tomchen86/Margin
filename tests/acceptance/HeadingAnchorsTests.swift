import Foundation
import Testing

/// docs/specs/markdown/spec.md, heading anchors, through the reader.
@MainActor
@Suite(.serialized)
struct HeadingAnchorsTests {
    @Test("[MARKDOWN-16.1] gives every heading GitHub's id for its text, numbering repeats")
    func givesGitHubsIDs() async throws {
        let markdown = """
            # Hello World

            ## Foo & Bar

            ## What's new?

            ## C++ and C#

            ## snake_case and kebab-case

            ## 1. Introduction

            ## Ünïcödé Café

            ## 中文標題

            ## 標題：說明

            ## Use `code` here

            ## Hello *world*

            ### Notes

            ### Notes

            ### Notes

            Setext Heading
            ==============

            > ## Quoted

            <h2 id="custom">Custom heading</h2>

            <h3>Raw heading</h3>
            """
        let shown = try await ShownDocument.show(markdown, named: "Headings.md")
        defer { shown.close() }
        let ids = try await shown.json(
            [String].self, "return [...document.querySelectorAll('h1, h2, h3, h4, h5, h6')].map(h => h.id)")
        #expect(
            ids == [
                "hello-world", "foo--bar", "whats-new", "c-and-c", "snake_case-and-kebab-case", "1-introduction",
                "ünïcödé-café", "中文標題", "標題說明", "use-code-here", "hello-world-1", "notes", "notes-1", "notes-2",
                "setext-heading", "quoted", "custom", "raw-heading",
            ])
    }

    @Test("[MARKDOWN-16.1] gives each id to one heading only")
    func givesUniqueIDs() async throws {
        let markdown = (1...5).map { _ in "## Same\n\nText." }.joined(separator: "\n\n")
        let shown = try await ShownDocument.show(markdown, named: "Same.md")
        defer { shown.close() }
        let ids = try await shown.json(
            [String].self, "return [...document.querySelectorAll('h2')].map(h => h.id)")
        #expect(ids == ["same", "same-1", "same-2", "same-3", "same-4"])
        let found = try await shown.json(
            [Bool].self, "return ['same', 'same-4'].map(id => document.getElementById(id)?.tagName === 'H2')")
        #expect(found == [true, true], "each id finds its heading")
    }
}
