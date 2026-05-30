#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

for path in ${CHECK_PATHS:-}; do
  [ -z "$path" ] && continue
  started=$(date '+%Y-%m-%dT%H:%M:%S')
  start_sec=$(date +%s)
  testdir="$path/cluster_acceptance_${USER:-user}_$$"
  logfile="$RUN_DIR/logs/filesystem_$(safe_name "$path").log"
  if mkdir -p "$testdir" > "$logfile" 2>&1 && echo "cluster acceptance test" > "$testdir/test.txt" && grep -q "cluster acceptance" "$testdir/test.txt" && rm -rf "$testdir"; then
    status="PASS"; reason="read/write/delete ok: $path"
  else
    status="FAIL"; reason="filesystem check failed: $path"
  fi
  ended=$(date '+%Y-%m-%dT%H:%M:%S')
  end_sec=$(date +%s)
  record_result "filesystem:$path" "sanity" "login" "" "" "$status" "$reason" "$started" "$ended" "$((end_sec-start_sec))" "$logfile"
done
