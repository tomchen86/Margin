#!/usr/bin/env bash
# The one command CI and agents run: lint, format check, typecheck, tests, then the
# requirement trace. Contract for the block below: exit non-zero if anything fails, and
# have the tests write JUnit XML into reports/junit/ so scripts/trace_check.py can see
# which requirements pass.
set -euo pipefail
cd "$(dirname "$0")/.."
# Start empty: a stale report would let a removed or now-skipped test still count.
rm -rf reports/junit && mkdir -p reports/junit
# The trace runs last, even when a step below fails: in the red phase its report is the
# point. Keep this line when you replace the block.
trap 'status=$?; python3 scripts/trace_check.py || status=1; exit "$status"' EXIT

# Lint and format check, then build (the typecheck) and test on a simulator. The tests run
# even when lint fails, so one run reports both.
status=0
xcrun swift-format lint --strict --recursive . || status=1
bash scripts/test.sh || status=1
exit "$status"
