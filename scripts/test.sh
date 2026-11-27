#!/usr/bin/env bash
# Build and run the tests on one iOS simulator, then write their results as JUnit XML into
# reports/junit/ for scripts/trace_check.py. The result bundle stays at reports/tests.xcresult.
#
#   usage: bash scripts/test.sh [xcodebuild arguments]
#   e.g.   bash scripts/test.sh -only-testing:MarginTests/ReaderTests
#
# MARGIN_DESTINATION picks the simulator, as an xcodebuild -destination value: a simulator of
# your own on a shared machine, e.g. MARGIN_DESTINATION=id=<UDID> (AGENTS.md, rule 8). CI sets
# it in .github/workflows/ci.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MARGIN_DESTINATION:?set it to your own simulator, e.g. MARGIN_DESTINATION=id=<UDID> (AGENTS.md, rule 8)}"

# Each test target builds every file in its folder. A target whose folder holds no Swift file
# is still built but not run: Xcode relinks an empty test bundle without signing it again, and
# the simulator then refuses to load it.
skip=()
for target_folder in MarginAcceptanceTests:tests/acceptance MarginAcceptanceUITests:tests/acceptance-ui \
  MarginTests:tests/unit; do
  if [ -z "$(find "${target_folder#*:}" -name '*.swift' -print -quit)" ]; then
    skip+=("-skip-testing:${target_folder%%:*}")
  fi
done

results=reports/tests.xcresult
rm -rf "$results" && mkdir -p reports/junit
status=0
xcodebuild test -quiet -project Margin.xcodeproj -scheme Margin -destination "$MARGIN_DESTINATION" \
  -resultBundlePath "$results" ${skip[@]+"${skip[@]}"} "$@" || status=$?
python3 scripts/xcresult_junit.py "$results" reports/junit/tests.xml || status=1
exit "$status"
