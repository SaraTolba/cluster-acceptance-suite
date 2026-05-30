#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/modules.sh"

issues_file="$ROOT_DIR/$KNOWN_ISSUES_FILE"
required_file="$ROOT_DIR/$REQUIRED_MODULES_FILE"
[ -f "$issues_file" ] || exit 0
[ -f "$required_file" ] || exit 0

while IFS='|' read -r kind pattern severity message; do
  kind=$(printf '%s' "$kind" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$kind" ] && continue
  [ "$kind" = "FORBIDDEN_MODULE_DEPENDENCY" ] || [ "$kind" = "MISSING_ENV_VAR_PATTERN" ] || continue
  severity="${severity:-WARN}"
  message="${message:-Pattern found}"
  found=0
  logfile="$RUN_DIR/logs/known_issue_$(safe_name "$pattern").log"
  : > "$logfile"
  while IFS= read -r mod; do
    mod=$(printf '%s' "$mod" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$mod" ] && continue
    if bash -lc "source /etc/profile >/dev/null 2>&1 || true; module show '$mod' 2>&1" | grep -q -- "$pattern"; then
      echo "$mod contains pattern: $pattern" >> "$logfile"
      found=1
    fi
  done < "$required_file"
  started=$(date '+%Y-%m-%dT%H:%M:%S')
  ended="$started"
  if [ "$found" -eq 1 ]; then
    record_result "known_issue:$pattern" "sanity" "modules" "" "" "$severity" "$message" "$started" "$ended" "0" "$logfile"
  else
    record_result "known_issue:$pattern" "sanity" "modules" "" "" "PASS" "pattern not found in required modules" "$started" "$ended" "0" "$logfile"
  fi
done < "$issues_file"
