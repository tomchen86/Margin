#!/usr/bin/env python3
"""Turn the test results in an Xcode result bundle into JUnit XML for scripts/trace_check.py.

  usage: python3 scripts/xcresult_junit.py <result bundle> <JUnit XML file>

Reads `xcrun xcresulttool get test-results tests`. Each Swift Testing or XCTest test case
becomes one <testcase>: classname is the test bundle and its suites, name is the test's
display name, followed by its function name when that differs, so an ID in either is seen:

  @Test("[MARKDOWN-1.1] renders headings") func headings()
    -> name="[MARKDOWN-1.1] renders headings (headings())"

Only "Passed" counts as passed. "Skipped" and "Expected Failure" (a test inside
withKnownIssue) become <skipped>, anything else <failure>, so neither cites a requirement.
A bundle with no test results, such as one from a failed build, writes no file.
"""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SKIPPED = {"Skipped", "Expected Failure"}
GROUPS = {"Unit test bundle", "UI test bundle", "Test Suite"}


def last_component(identifier):
    return identifier.rstrip("/").rsplit("/", 1)[-1] if identifier else ""


def label(node):
    name = node.get("name", "")
    identifier = last_component(node.get("nodeIdentifier") or node.get("nodeIdentifierURL", ""))
    return name if not identifier or identifier == name else f"{name} ({identifier})"


def messages(node):
    for child in node.get("children", []):
        if child.get("nodeType") == "Failure Message":
            yield child.get("name", "")
        yield from messages(child)


def cases(node, path):
    """Yields (bundle, classname, name, node) for every test case below node."""
    kind = node.get("nodeType")
    if kind == "Test Case":
        yield path[0] if path else "", "/".join(path), label(node), node
        return
    if kind in GROUPS:
        path = path + [label(node)]
    # Any other node (the test plan, a device, a configuration, a kind added later) is looked through.
    for child in node.get("children", []):
        yield from cases(child, path)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: xcresult_junit.py <result bundle> <JUnit XML file>")
    bundle, out = Path(sys.argv[1]), Path(sys.argv[2])
    if not bundle.exists():
        print(f"xcresult_junit: no result bundle at {bundle}: no test results to report", file=sys.stderr)
        return 0
    run = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(bundle)],
        capture_output=True,
        text=True,
    )
    if run.returncode != 0:
        print(f"xcresult_junit: {bundle} has no test results: {run.stderr.strip()}", file=sys.stderr)
        return 0
    results = json.loads(run.stdout)

    suites, counts = {}, {"passed": 0, "skipped": 0, "failed": 0}
    for root in results.get("testNodes", []):
        for bundle_name, classname, name, node in cases(root, []):
            suite = suites.setdefault(bundle_name, ET.Element("testsuite", name=bundle_name))
            case = ET.SubElement(suite, "testcase", classname=classname, name=name)
            if "durationInSeconds" in node:
                case.set("time", f"{node['durationInSeconds']:.3f}")
            result = node.get("result", "")
            if result == "Passed":
                counts["passed"] += 1
                continue
            text = "\n".join(messages(node))
            if result in SKIPPED:
                counts["skipped"] += 1
                ET.SubElement(case, "skipped", message=result)
            else:
                counts["failed"] += 1
                ET.SubElement(case, "failure", message=result or "unknown result").text = text
                # xcodebuild -quiet lists only failing identifiers; say what failed and why.
                print(f"FAILED {classname} {name}", *text.splitlines(), sep="\n    ", file=sys.stderr)

    report = ET.Element("testsuites")
    for suite in suites.values():
        testcases = suite.findall("testcase")
        suite.set("tests", str(len(testcases)))
        suite.set("failures", str(sum(1 for c in testcases if c.find("failure") is not None)))
        suite.set("skipped", str(sum(1 for c in testcases if c.find("skipped") is not None)))
        report.append(suite)
    out.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(report).write(out, encoding="utf-8", xml_declaration=True)
    summary = ", ".join(f"{n} {label}" for label, n in counts.items())
    print(f"xcresult_junit: {summary}; written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
