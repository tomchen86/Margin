// Turns the page's Markdown source into HTML. Together with the bundled libraries,
// this is the only script the reader page's Content Security Policy lets run:
// scripts or event handlers inside the document itself are blocked.
(() => {
  "use strict";

  const article = document.querySelector("article");
  const source = JSON.parse(document.getElementById("margin-source").textContent);

  try {
    const md = window.markdownit({
      html: true,
      linkify: true,
      highlight(code, language) {
        if (language && hljs.getLanguage(language)) {
          try {
            return hljs.highlight(code, { language, ignoreIllegals: true }).value;
          } catch {}
        }
        return ""; // markdown-it escapes the code itself
      },
    });
    md.use(window.markdownitFootnote);
    md.use(math);

    article.innerHTML = md.render(source);
    markTasks(article);
    addHeadingIDs(article);
  } catch (error) {
    // Show the text rather than an empty page if a library failed to load.
    const pre = document.createElement("pre");
    pre.className = "plain";
    pre.textContent = source;
    article.replaceChildren(pre);
  }

  document.documentElement.dataset.readyMs = String(Math.round(performance.now()));

  // $inline$ and $$display$$ math. Recognised while parsing, so `*`, `_` and `\`
  // inside a formula never reach Markdown's own emphasis and escape rules.
  function math(md) {
    md.inline.ruler.after("escape", "math_inline", mathInline);
    md.block.ruler.before("fence", "math_block", mathBlock, {
      alt: ["paragraph", "reference", "blockquote", "list"],
    });
    md.renderer.rules.math_inline = (tokens, index) =>
      renderTeX(tokens[index].content, tokens[index].meta.display);
    md.renderer.rules.math_block = (tokens, index) =>
      `<div class="math-display">${renderTeX(tokens[index].content, true)}</div>\n`;
  }

  function renderTeX(tex, displayMode) {
    return katex.renderToString(tex, { displayMode, throwOnError: false });
  }

  function mathInline(state, silent) {
    const src = state.src;
    const start = state.pos;
    if (src[start] !== "$") return false;
    const display = src[start + 1] === "$";
    const fence = display ? 2 : 1;
    const contentStart = start + fence;
    // "$5 and $10" is money, not math: an inline formula can't start with a space.
    if (!display && (contentStart >= state.posMax || /\s/.test(src[contentStart]))) return false;

    let end = -1;
    for (let i = contentStart; i < state.posMax; i++) {
      if (src[i] === "\\") { i++; continue; }
      if (src[i] !== "$") continue;
      if (!display || src[i + 1] === "$") { end = i; break; }
    }
    if (end <= contentStart) return false;
    // …and can't end with a space or be followed by a digit.
    if (!display && (/\s/.test(src[end - 1]) || /\d/.test(src[end + 1] ?? ""))) return false;

    if (!silent) {
      const token = state.push("math_inline", "math", 0);
      token.content = src.slice(contentStart, end);
      token.markup = display ? "$$" : "$";
      token.meta = { display };
    }
    state.pos = end + fence;
    return true;
  }

  function mathBlock(state, startLine, endLine, silent) {
    const start = state.bMarks[startLine] + state.tShift[startLine];
    if (state.sCount[startLine] - state.blkIndent >= 4) return false;
    if (state.src.slice(start, start + 2) !== "$$") return false;

    const first = state.src.slice(start + 2, state.eMarks[startLine]).trim();
    let content;
    let last = startLine;
    if (first.length > 2 && first.endsWith("$$")) {
      content = first.slice(0, -2); // $$ x $$ on one line
    } else {
      const lines = [first];
      let closed = false;
      for (last = startLine + 1; last < endLine; last++) {
        const lineStart = state.bMarks[last] + state.tShift[last];
        const lineEnd = state.eMarks[last];
        if (lineStart < lineEnd && state.sCount[last] < state.blkIndent) break;
        const text = state.src.slice(lineStart, lineEnd).trimEnd();
        if (text.endsWith("$$")) {
          lines.push(text.slice(0, -2));
          closed = true;
          break;
        }
        lines.push(text);
      }
      if (!closed) return false;
      content = lines.join("\n");
    }
    if (silent) return true;

    state.line = last + 1;
    const token = state.push("math_block", "math", 0);
    token.block = true;
    token.content = content;
    token.markup = "$$";
    token.map = [startLine, state.line];
    return true;
  }

  // "- [ ] item" and "- [x] item" become disabled checkboxes.
  function markTasks(root) {
    for (const item of root.querySelectorAll("li")) {
      let host = item;
      let first = firstContent(item);
      if (first?.nodeName === "P") {
        host = first;
        first = firstContent(first);
      }
      if (first?.nodeType !== Node.TEXT_NODE) continue;
      const match = /^\[([ xX])\][ \t]/.exec(first.data);
      if (!match) continue;
      first.data = first.data.slice(match[0].length);
      const box = document.createElement("input");
      box.type = "checkbox";
      box.disabled = true;
      box.checked = match[1] !== " ";
      host.insertBefore(box, first);
      item.classList.add("task");
    }
  }

  function firstContent(node) {
    let child = node.firstChild;
    while (child?.nodeType === Node.TEXT_NODE && !child.data.trim()) child = child.nextSibling;
    return child;
  }

  // Every heading gets an id, so "#heading" links and a table of contents can point at it.
  function addHeadingIDs(root) {
    const used = new Set();
    for (const heading of root.querySelectorAll("h1, h2, h3, h4, h5, h6")) {
      if (heading.id) { used.add(heading.id); continue; }
      const base = heading.textContent.trim().toLowerCase()
        .replace(/[^\p{L}\p{N}\s_-]/gu, "")
        .replace(/\s+/g, "-") || "section";
      let id = base;
      for (let n = 1; used.has(id) || document.getElementById(id); n++) id = `${base}-${n}`;
      used.add(id);
      heading.id = id;
    }
  }
})();
