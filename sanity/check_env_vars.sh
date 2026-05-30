#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
start_sec=$(date +%s)
missing=""
for var in HOME PATH; do
  if [ -z "${!var:-}" ]; then
    missing="$missing $var"
  fi
done
if [ -z "${MODULEPATH:-}" ]; then
  missing="$missing MODULEPATH"
fi
ended=$(date '+%Y-%m-%dT%H:%M:%S')
end_sec=$(date +%s)
if [ -n "$missing" ]; then
  record_result "check_env_vars" "sanity" "login" "" "" "FAIL" "Missing env vars:$missing" "$started" "$ended" "$((end_sec-start_sec))" ""
else
  record_result "check_env_vars" "sanity" "login" "" "" "PASS" "required env vars present" "$started" "$ended" "$((end_sec-start_sec))" ""
fi
