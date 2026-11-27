#!/usr/bin/env python3
"""What a test run left unexecuted, from LLVM coverage data. Used by scripts/coverage.sh.

  usage: python3 scripts/coverage_report.py <profdata> <binary>... [-- <source file>...]

Prints, for each source file outside tests/, its function and region counts, then every
function no test called and every region no test executed in a function that did run.
With source files after --, only those files. Swift's coverage counts regions, not
branches: each side of an if, guard, switch case, ?:, &&, or || is its own region.
"""
import json
import os
import subprocess
import sys

REPO = os.path.realpath(os.path.join(os.path.dirname(__file__), ".."))
CODE_REGION = 0


def relative(path):
    return os.path.relpath(os.path.realpath(path), REPO)


def demangle(names):
    run = subprocess.run(
        ["xcrun", "swift-demangle", "--simplified"], input="\n".join(names), capture_output=True, text=True
    )
    lines = run.stdout.splitlines()
    return dict(zip(names, lines)) if run.returncode == 0 and len(lines) == len(names) else {n: n for n in names}


def main():
    args = sys.argv[1:]
    sources = None
    if "--" in args:
        split = args.index("--")
        args, sources = args[:split], {relative(f) for f in args[split + 1 :]} or None
    if len(args) < 2:
        sys.exit("usage: coverage_report.py <profdata> <binary>... [-- <source file>...]")
    profdata, binaries = args[0], args[1:]
    command = ["xcrun", "llvm-cov", "export", "-format=text", "-instr-profile", profdata, binaries[0]]
    for binary in binaries[1:]:
        command += ["-object", binary]
    export = json.loads(subprocess.run(command, capture_output=True, text=True, check=True).stdout)["data"][0]

    def wanted(path):
        path = relative(path)
        return not path.startswith(("tests/", "..")) and (sources is None or path in sources)

    print(f"{'functions':>10} {'regions':>10}  file")
    for entry in sorted(export["files"], key=lambda e: relative(e["filename"])):
        if wanted(entry["filename"]):
            functions, regions = entry["summary"]["functions"], entry["summary"]["regions"]
            print(
                f"{functions['covered']:>4} of {functions['count']:<3} {regions['covered']:>4} of {regions['count']:<3}"
                f"  {relative(entry['filename'])}"
            )

    missed = []
    functions = [f for f in export["functions"] if f["filenames"] and wanted(f["filenames"][0])]
    names = demangle([f["name"] for f in functions])
    for function in functions:
        paths = [relative(f) for f in function["filenames"]]
        line, column, _, _, _, file_id, _, _ = function["regions"][0]
        if function["count"] == 0:
            missed.append((paths[file_id], line, column, f"function never called: {names[function['name']]}"))
            continue
        for line, column, end_line, end_column, count, file_id, _, kind in function["regions"]:
            if count == 0 and kind == CODE_REGION:
                missed.append((paths[file_id], line, column, f"region never executed, to {end_line}:{end_column}"))
    print("\nnot executed:" if missed else "\nnot executed: nothing")
    for path, line, column, what in sorted(set(missed)):
        print(f"  {path}:{line}:{column}  {what}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
