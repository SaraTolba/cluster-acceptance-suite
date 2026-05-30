#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/modules.sh"

module_file="$ROOT_DIR/$REQUIRED_MODULES_FILE"
[ -f "$module_file" ] || { record_result "check_required_modules" "sanity" "login" "" "" "FAIL" "Missing required modules file: $module_file" "" "" "" ""; exit 0; }

while IFS= read -r mod; do
  mod=$(printf '%s' "$mod" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$mod" ] && continue
  started=$(date '+%Y-%m-%dT%H:%M:%S')
  start_sec=$(date +%s)
  logfile="$RUN_DIR/logs/required_module_$(safe_name "$mod").log"
  if bash -lc "source /etc/profile >/dev/null 2>&1 || true; module purge >/dev/null 2>&1 || true; module load '$mod'; module list" > "$logfile" 2>&1; then
    status="PASS"; reason="module loaded: $mod"
  else
    status="FAIL"; reason="module failed to load: $mod"
  fi
  ended=$(date '+%Y-%m-%dT%H:%M:%S')
  end_sec=$(date +%s)
  record_result "required_module:$mod" "sanity" "login" "" "" "$status" "$reason" "$started" "$ended" "$((end_sec-start_sec))" "$logfile"
done < "$module_file"
