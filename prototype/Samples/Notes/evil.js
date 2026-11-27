// Test file for Security.md: if this ever runs, the CSP failed.
window.__pwned = "evil.js";
document.body.style.background = "red";
document.body.insertAdjacentText("afterbegin", "PWNED evil.js");
