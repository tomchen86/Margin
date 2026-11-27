# CSP 測試

這頁夾帶了幾種會執行 JavaScript 的寫法。CSP 有擋住的話：背景維持原色，下面也不會出現「PWNED」。

<script>window.__pwned = "inline script"; document.body.style.background = "red";</script>

<script src="evil.js"></script>

<img src="does-not-exist.png" onerror="window.__pwned = 'onerror'; document.body.style.background = 'red'; this.insertAdjacentText('afterend', 'PWNED onerror')">

<svg onload="window.__pwned = 'svg onload'; document.body.style.background = 'red'"></svg>

<iframe srcdoc="<script>parent.__pwned = 'iframe'; parent.document.body.style.background = 'red'</script>"></iframe>

<a href="javascript:window.__pwned='javascript link'; document.body.style.background='red'">點這個 javascript: 連結</a>

<details open ontoggle="window.__pwned = 'ontoggle'; document.body.style.background = 'red'"><summary>details ontoggle</summary>內容</details>

一般的 HTML 照常顯示：<kbd>⌘</kbd> + <kbd>F</kbd>，<mark>標記</mark>。

網路上的 iframe 跟網路圖片一樣照常載入（下面應該看到 example.com）：

<iframe src="https://example.com" width="320" height="180"></iframe>

本機檔案的 iframe 會被擋（下面應該是空框）：

<iframe src="Report.html" width="320" height="120"></iframe>
