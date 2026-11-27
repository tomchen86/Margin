#!/usr/bin/env bash
# Traced coverage (skills/review-pr, step 6): run only the acceptance tests, the ones that cite
# requirement IDs, with coverage on (UI tests count for the app they launch), then list what they
# left unexecuted in the app and in MarginReader: functions no acceptance test called, and regions
# none executed. Swift's coverage counts regions, not branches; each side of an if, guard, switch
# case, ?:, &&, or || is a region.
#
#   usage: bash scripts/coverage.sh [source file ...]   (default: every source file)
#
# Runs on the simulator in MARGIN_DESTINATION, like scripts/test.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MARGIN_DESTINATION:?set it to your own simulator, e.g. MARGIN_DESTINATION=id=<UDID> (AGENTS.md, rule 8)}"

# The acceptance targets that hold tests; scripts/test.sh skips the empty ones.
only=()
for target_folder in MarginAcceptanceTests:tests/acceptance MarginAcceptanceUITests:tests/acceptance-ui; do
  if [ -n "$(find "${target_folder#*:}" -name '*.swift' -print -quit)" ]; then
    only+=("-only-testing:${target_folder%%:*}")
  fi
done
if [ ${#only[@]} -eq 0 ]; then
  echo "coverage.sh: tests/acceptance and tests/acceptance-ui hold no tests, so no acceptance test executes any code"
  exit 0
fi

products=$(xcodebuild -project Margin.xcodeproj -scheme Margin -destination "$MARGIN_DESTINATION" -showBuildSettings 2>/dev/null |
  sed -n 's/^ *CONFIGURATION_BUILD_DIR = //p' | head -n 1)
[ -n "$products" ] || { echo "coverage.sh: xcodebuild -showBuildSettings found no build directory" >&2; exit 1; }
profiles="$(dirname "$(dirname "$products")")/ProfileData"
# Start empty, so a failed run cannot report an earlier run's counts.
rm -rf "$profiles"

status=0
bash scripts/test.sh "${only[@]}" -enableCodeCoverage YES || status=$?
profdata=$(find "$profiles" -name Coverage.profdata 2>/dev/null | head -n 1)
if [ -z "$profdata" ]; then
  echo "coverage.sh: the test run left no coverage data in $profiles" >&2
  exit 1
fi
# The app's code, MarginReader included, is in its debug dylib in Debug builds, else in its executable.
binaries=()
for binary in "$products/Margin.app/Margin.debug.dylib" "$products/Margin.app/Margin"; do
  [ -f "$binary" ] && binaries+=("$binary")
done
[ ${#binaries[@]} -gt 0 ] || { echo "coverage.sh: no app binary in $products/Margin.app" >&2; exit 1; }
python3 scripts/coverage_report.py "$profdata" "${binaries[@]}" -- "$@" || status=1
exit "$status"
