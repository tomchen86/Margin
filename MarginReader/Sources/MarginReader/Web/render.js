// Renders the page's Markdown source into its <article>. With the bundled markdown-it and
// markdown-it-footnote, this is the only script the page's Content Security Policy lets run.
(() => {
  "use strict";

  const article = document.querySelector("article");
  const source = JSON.parse(document.getElementById("source").textContent).replace(/\r\n?/g, "\n");

  try {
    const { frontMatter, body } = splitFrontMatter(source);
    const md = window.markdownit({ html: true, linkify: true, typographer: false, breaks: false });
    md.use(window.markdownitFootnote);
    linkOnlyAddressesWithSchemeOrWWW(md.linkify);
    md.renderer.rules.footnote_caption = (tokens, index) => String(tokens[index].meta.id + 1);
    md.core.ruler.push("task_lists", taskLists);

    // A template parses the HTML without loading or running anything, so the unsafe parts can
    // be taken out before the page sees them.
    const template = document.createElement("template");
    template.innerHTML = md.render(body);
    removeWhatThePolicyCannotStop(template.content);
    addHeadingAnchors(template.content);
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

  // Every heading gets GitHub's id for its text, so links written for GitHub find it. A heading
  // whose own HTML has an id keeps it, and a repeat of any id in the document is numbered.
  function addHeadingAnchors(root) {
    const used = new Set([...root.querySelectorAll("[id]")].map((element) => element.id));
    const repeats = new Map();
    for (const heading of root.querySelectorAll("h1, h2, h3, h4, h5, h6")) {
      if (heading.id) continue;
      const base = gitHubSlug(heading.textContent);
      let id = base;
      while (used.has(id)) {
        const count = (repeats.get(base) ?? 0) + 1;
        repeats.set(base, count);
        id = `${base}-${count}`;
      }
      used.add(id);
      heading.id = id;
    }
  }

  // Lowercase; letters, marks, numbers, "_", "-", and spaces kept, everything else dropped; each
  // space a "-".
  function gitHubSlug(text) {
    return text.trim().toLowerCase().replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, "").replace(/ /g, "-");
  }

  // WebKit doesn't apply the policy's frame-src to srcdoc frames, and a <meta> or <base> added
  // to the page could navigate it or change where its links point.
  function removeWhatThePolicyCannotStop(root) {
    for (const frame of root.querySelectorAll("iframe[srcdoc]")) frame.removeAttribute("srcdoc");
    for (const element of root.querySelectorAll("meta, base")) element.remove();
  }
})();
