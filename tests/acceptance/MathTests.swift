import Foundation
import Testing

/// docs/specs/markdown/spec.md, math, through the reader.
@MainActor
@Suite(.serialized)
struct MathTests {
    @Test("[MARKDOWN-17.1] typesets inline and display formulas with the app's math fonts, as typed")
    func typesetsFormulas() async throws {
        let markdown = #"""
            Inline $a*b*c$ and $\{x\}$ here.

            $$\sum_{i=1}^n i$$
            """#
        let shown = try await ShownDocument.show(markdown, named: "Math.md")
        defer { shown.close() }
        let page = try await shown.formulas()
        #expect(page.map(\.source) == [#"a*b*c"#, #"\{x\}"#, #"\sum_{i=1}^n i"#], "each formula as typed")
        #expect(page.map(\.display) == [false, false, true], "inline, inline, display")
        let emphasis = try await shown.evaluate("return document.querySelectorAll('p > em, p > strong').length")
        #expect(emphasis as? Int == 0, "the * did not become emphasis")
        let fonts = try await shown.json(
            [Bool].self,
            """
            await document.fonts.ready;
            return ["KaTeX_Main", "KaTeX_Math"].map(family => document.fonts.check(`16px ${family}`));
            """)
        #expect(fonts == [true, true], "the app's math fonts are loaded")
    }

    @Test("[MARKDOWN-17.1] shows $$…$$ inside a sentence as display math on its own line")
    func showsDisplayMathInASentence() async throws {
        let shown = try await ShownDocument.show(#"The area is $$\pi r^2$$ for a circle."#, named: "Inline display.md")
        defer { shown.close() }
        let page = try await shown.formulas()
        #expect(page.map(\.source) == [#"\pi r^2"#])
        #expect(page.map(\.display) == [true], "display math")
        let lines = try await shown.json(
            [Double].self,
            """
            const formula = document.querySelector("annotation")?.closest(".katex-display") ?? null;
            const range = document.createRange();
            const words = [...document.querySelectorAll("p")].find(p => p.textContent.includes("The area is"));
            if (!formula || !words) return [];
            range.setStart(words.firstChild, 0);
            range.setEnd(words.firstChild, "The area is".length);
            return [range.getBoundingClientRect().bottom, formula.getBoundingClientRect().top];
            """)
        #expect(lines.count == 2 && lines[1] >= lines[0], "the formula starts below the words before it: \(lines)")
    }

    @Test("[MARKDOWN-18.1] shows an invalid formula's source in red and typesets the rest")
    func marksInvalidFormulas() async throws {
        let shown = try await ShownDocument.show(#"Bad $\frac{a$, good $x^2$, after."#, named: "Invalid.md")
        defer { shown.close() }
        struct Page: Decodable {
            let error: String?
            let red: Bool
            let after: Bool
        }
        let page = try await shown.json(
            Page.self,
            #"""
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let error = null, red = false;
            for (let node = walker.nextNode(); node; node = walker.nextNode()) {
              if (!node.data.includes("\\frac{a")) continue;
              error = node.data.trim();
              const [r, g, b] = getComputedStyle(node.parentElement).color.match(/[\d.]+/g).map(Number);
              red = r > 150 && g < 100 && b < 100;
              break;
            }
            return { error, red, after: document.body.innerText.includes("after.") };
            """#)
        #expect(page.error?.contains(#"\frac{a"#) == true, "the invalid formula's source stands where it was")
        #expect(page.red, "in red")
        #expect(page.after, "the rest of the page follows")
        #expect(try await shown.formulas().map(\.source) == ["x^2"], "the valid formula is typeset")
    }

    @Test("[MARKDOWN-19.1] shows prices, spaced dollars, escaped dollars, and code as text")
    func keepsDollarsAsText() async throws {
        let markdown = #"""
            It costs $5 and $10.

            Spaced: $ x$ and $x $.

            Escaped: \$x\$.

            Code: `$y$`.

            Parentheses: \(z\).

            Real: $x^2$.
            """#
        let shown = try await ShownDocument.show(markdown, named: "Dollars.md")
        defer { shown.close() }
        #expect(try await shown.formulas().map(\.source) == ["x^2"], "only the real formula is typeset")
        let text = try await shown.visibleText()
        for expected in [
            "It costs $5 and $10.", "Spaced: $ x$ and $x $.", "Escaped: $x$.", "Code: $y$.", "Parentheses: (z).",
        ] {
            #expect(text.contains(expected), "shows \(expected)")
        }
        let code = try await shown.evaluate("return document.querySelector('p code')?.textContent ?? null")
        #expect(code as? String == "$y$", "the dollars in code stay code")
    }

    @Test("[MARKDOWN-20.1] scrolls a wide display formula inside itself, never the page")
    func scrollsWideFormulas() async throws {
        let sum = (1...60).map { "x_{\($0)}" }.joined(separator: " + ")
        let shown = try await ShownDocument.show("Before.\n\n$$\(sum)$$\n\nAfter.", named: "Wide math.md")
        defer { shown.close() }
        #expect(try await shown.formulas().count == 1, "the formula is typeset")
        let page = try await shown.json(
            [Bool].self,
            """
            const formula = document.querySelector("annotation")?.closest(".katex-display") ?? null;
            let scrolls = false;
            for (let e = formula; e && e !== document.body; e = e.parentElement) {
              const overflow = getComputedStyle(e).overflowX;
              if ((overflow === "auto" || overflow === "scroll") && e.scrollWidth > e.clientWidth
                  && e.getBoundingClientRect().right <= innerWidth) { scrolls = true; break; }
            }
            return [scrolls, document.documentElement.scrollWidth <= innerWidth];
            """)
        #expect(page == [true, true], "the formula scrolls inside itself, the page does not: \(page)")
    }
}

/// One typeset formula: its TeX source as KaTeX recorded it, and whether it is display math.
private struct Formula: Decodable {
    let source: String
    let display: Bool
}

extension ShownDocument {
    /// The formulas KaTeX typeset on the page, in order.
    fileprivate func formulas() async throws -> [Formula] {
        try await json(
            [Formula].self,
            """
            return [...document.querySelectorAll('annotation[encoding="application/x-tex"]')].map(a => ({
              source: a.textContent, display: !!a.closest(".katex-display")
            }));
            """)
    }
}
