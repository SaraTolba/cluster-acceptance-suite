#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
start_sec=$(date +%s)
file="$ROOT_DIR/$EXPECTED_LIMITS_FILE"
[ -f "$file" ] || { record_result "check_ulimits" "sanity" "login" "" "" "FAIL" "Missing expected limits file: $file" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""; exit 0; }
# shellcheck disable=SC1090
source "$file"

status="PASS"
reason="limits ok"

nofile=$(ulimit -n 2>/dev/null || echo 0)
if [ "${ULIMIT_NOFILE_MIN:-0}" -gt 0 ] && [ "$nofile" -lt "$ULIMIT_NOFILE_MIN" ]; then
  status="FAIL"
  reason="ulimit -n is $nofile, expected >= $ULIMIT_NOFILE_MIN"
fi

if [ "${REQUIRE_MODULEPATH:-0}" -eq 1 ] && [ -z "${MODULEPATH:-}" ]; then
  status="FAIL"
  reason="MODULEPATH is empty"
fi

ended=$(date '+%Y-%m-%dT%H:%M:%S')
end_sec=$(date +%s)
record_result "check_ulimits" "sanity" "login" "" "" "$status" "$reason" "$started" "$ended" "$((end_sec-start_sec))" ""
