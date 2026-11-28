// Renders the page's Markdown source into its <article>. With the bundled markdown-it,
// markdown-it-footnote, and KaTeX, this is the only script the page's Content Security Policy
// lets run.
(() => {
  "use strict";

  const article = document.querySelector("article");
  const source = JSON.parse(document.getElementById("source").textContent).replace(/\r\n?/g, "\n");

  try {
    const { frontMatter, body } = splitFrontMatter(source);
    const md = window.markdownit({ html: true, linkify: true, typographer: false, breaks: false });
    md.use(window.markdownitFootnote);
    md.use(math);
    linkOnlyAddressesWithSchemeOrWWW(md.linkify);
    md.renderer.rules.footnote_caption = (tokens, index) => String(tokens[index].meta.id + 1);
    md.core.ruler.push("task_lists", taskLists);

    // A template parses the HTML without loading or running anything, so the unsafe parts can
    // be taken out before the page sees them.
    const template = document.createElement("template");
    template.innerHTML = md.render(body);
    removeWhatThePolicyCannotStop(template.content);
    if (frontMatter !== null) template.content.prepend(preformatted(frontMatter, "front-matter"));
    article.replaceChildren(template.content);
  } catch (error) {
    // A library that failed to load leaves the text, not an empty page.
    article.replaceChildren(preformatted(source, "source"));
  }

  // Front matter is the lines between a first line of "---" and the next line of "---".
  function splitFrontMatter(text) {
    const lines = text.split("\n");
    const end = lines[0] === "---" ? lines.indexOf("---", 1) : -1;
    if (end < 0) return { frontMatter: null, body: text };
    return { frontMatter: lines.slice(1, end).join("\n"), body: lines.slice(end + 1).join("\n") };
  }

  function preformatted(text, className) {
    const pre = document.createElement("pre");
    const code = document.createElement("code");
    pre.className = className;
    code.textContent = text;
    pre.append(code);
    return pre;
  }

  // Bare text becomes a link only with a scheme (https:, http:, mailto: for e-mail addresses)
  // or a leading "www."; bare domains and file names such as README.md stay text. linkify-it
  // finds "www." addresses only together with every bare domain, so it finds them all and the
  // rest are dropped. markdown-it asks test() before match(), so both answer the same.
  function linkOnlyAddressesWithSchemeOrWWW(linkify) {
    linkify.set({ fuzzyLink: true });
    const match = linkify.match.bind(linkify);
    const kept = (found) => found.schema !== "" || /^www\./i.test(found.raw);
    linkify.match = (text) => {
      const found = (match(text) || []).filter(kept);
      return found.length > 0 ? found : null;
    };
    linkify.test = (text) => linkify.match(text) !== null;
  }

  // $…$ and $$…$$ formulas, typeset by KaTeX. They are recognized while parsing, so Markdown never
  // sees the formula's characters: `*`, `_`, and `\` reach KaTeX as typed.
  function math(md) {
    md.inline.ruler.after("escape", "math_inline", mathInline);
    md.block.ruler.before("fence", "math_block", mathBlock, { alt: ["paragraph", "reference", "blockquote", "list"] });
    md.renderer.rules.math_inline = (tokens, index) => typeset(tokens[index].content, tokens[index].meta.display);
    md.renderer.rules.math_block = (tokens, index) => `<div class="math">${typeset(tokens[index].content, true)}</div>\n`;
  }

  // An invalid formula shows its source in red where it stands (throwOnError: false).
  function typeset(source, displayMode) {
    return window.katex.renderToString(source, { displayMode, throwOnError: false });
  }

  // $…$ inline, and $$…$$ as display math, inside a sentence too. A $ is not a formula's when the
  // opening $ is followed by a space, or the closing $ follows a space or comes before a digit, so
  // prices such as "$5 and $10" stay text. An escaped \$ never reaches this rule.
  function mathInline(state, silent) {
    const source = state.src;
    const start = state.pos;
    if (source[start] !== "$") return false;
    const display = source[start + 1] === "$";
    const marker = display ? 2 : 1;
    const contentStart = start + marker;
    if (contentStart >= state.posMax || (!display && /\s/.test(source[contentStart]))) return false;
    let end = -1;
    for (let index = contentStart; index < state.posMax; index++) {
      if (source[index] === "\\") {
        index++;
      } else if (source[index] === "$" && (!display || source[index + 1] === "$")) {
        end = index;
        break;
      }
    }
    if (end <= contentStart) return false;
    if (!display && (/\s/.test(source[end - 1]) || /[0-9]/.test(source[end + 1] ?? ""))) return false;
    if (!silent) {
      const token = state.push("math_inline", "math", 0);
      token.content = source.slice(contentStart, end);
      token.markup = display ? "$$" : "$";
      token.meta = { display };
    }
    state.pos = end + marker;
    return true;
  }

  // A $$ formula whose lines stand on their own, so its lines never become Markdown blocks.
  // When text follows the closing $$ on its line, the paragraph's inline rule handles it instead.
  function mathBlock(state, startLine, endLine, silent) {
    if (state.sCount[startLine] - state.blkIndent >= 4) return false;
    const lineText = (line) => state.src.slice(state.bMarks[line] + state.tShift[line], state.eMarks[line]);
    const first = lineText(startLine);
    if (!first.startsWith("$$")) return false;
    const lines = [];
    let last = startLine;
    let rest = first.slice(2);
    for (;;) {
      const close = rest.indexOf("$$");
      if (close >= 0) {
        if (rest.slice(close + 2).trim() !== "") return false;
        lines.push(rest.slice(0, close));
        break;
      }
      lines.push(rest);
      last++;
      if (last >= endLine || (state.sCount[last] < state.blkIndent && lineText(last) !== "")) return false;
      rest = lineText(last);
    }
    if (silent) return true;
    const token = state.push("math_block", "math", 0);
    token.block = true;
    token.content = lines.join("\n");
    token.markup = "$$";
    token.map = [startLine, last + 1];
    state.line = last + 1;
    return true;
  }

  // A list item whose text starts with "[ ] ", "[x] ", or "[X] " starts with a disabled checkbox.
  function taskLists(state) {
    const tokens = state.tokens;
    for (let index = 2; index < tokens.length; index++) {
      const inline = tokens[index];
      if (inline.type !== "inline" || tokens[index - 1].type !== "paragraph_open") continue;
      if (tokens[index - 2].type !== "list_item_open") continue;
      const first = inline.children[0];
      const marker = first && first.type === "text" ? /^\[([ xX])\] /.exec(first.content) : null;
      if (!marker) continue;
      first.content = first.content.slice(marker[0].length);
      const box = new state.Token("html_inline", "", 0);
      box.content = `<input type="checkbox" disabled${marker[1] === " " ? "" : " checked"}>`;
      inline.children.unshift(box);
      tokens[index - 2].attrJoin("class", "task-list-item");
    }
  }

  // WebKit doesn't apply the policy's frame-src to srcdoc frames, and a <meta> or <base> added
  // to the page could navigate it or change where its links point.
  function removeWhatThePolicyCannotStop(root) {
    for (const frame of root.querySelectorAll("iframe[srcdoc]")) frame.removeAttribute("srcdoc");
    for (const element of root.querySelectorAll("meta, base")) element.remove();
  }
})();
