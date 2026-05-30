#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/modules.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
start_sec=$(date +%s)
logfile="$RUN_DIR/logs/module_avail.txt"
if ! module_cmd_available; then
  record_result "check_modules_avail" "sanity" "login" "" "" "FAIL" "module command not available" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi
if list_available_modules > "$logfile" 2>&1 && [ -s "$logfile" ]; then
  status="PASS"; reason="module avail returned output"
else
  status="FAIL"; reason="module avail failed or returned empty output"
fi
ended=$(date '+%Y-%m-%dT%H:%M:%S')
end_sec=$(date +%s)
record_result "check_modules_avail" "sanity" "login" "" "" "$status" "$reason" "$started" "$ended" "$((end_sec-start_sec))" "$logfile"
