#!/usr/bin/env bash

init_reporting() {
  mkdir -p "$RUN_DIR"
  RESULTS_CSV="$RUN_DIR/acceptance_results.csv"
  SUMMARY_MD="$RUN_DIR/acceptance_summary.md"
  export RESULTS_CSV SUMMARY_MD
  if [ ! -f "$RESULTS_CSV" ]; then
    printf 'run_id,cluster,scheduler,test_id,test_type,scope,node,job_id,status,reason,started_at,ended_at,elapsed_sec,log_path,command\n' > "$RESULTS_CSV"
  fi
}

csv_escape() {
  local value="${1:-}"
  # Escape double quotes by doubling them
  value=${value//\"/\"\"}
  # Remove newlines to avoid CSV line breaks
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  # Wrap in quotes
  printf '"%s"' "$value"
}

record_result() {
  local test_id="${1:-unknown}"
  local test_type="${2:-unknown}"
  local scope="${3:-global}"
  local node="${4:-}"
  local job_id="${5:-}"
  local status="${6:-UNKNOWN}"
  local reason="${7:-}"
  local started_at="${8:-}"
  local ended_at="${9:-}"
  local elapsed_sec="${10:-}"
  local log_path="${11:-}"
  local command="${12:-${CURRENT_COMMAND:-}}"

  : "${RESULTS_CSV:?RESULTS_CSV not set; call init_reporting}"
  {
    csv_escape "${RUN_ID:-}"; printf ','
    csv_escape "${CLUSTER_NAME:-}"; printf ','
    csv_escape "${SCHEDULER:-}"; printf ','
    csv_escape "$test_id"; printf ','
    csv_escape "$test_type"; printf ','
    csv_escape "$scope"; printf ','
    csv_escape "$node"; printf ','
    csv_escape "$job_id"; printf ','
    csv_escape "$status"; printf ','
    csv_escape "$reason"; printf ','
    csv_escape "$started_at"; printf ','
    csv_escape "$ended_at"; printf ','
    csv_escape "$elapsed_sec"; printf ','
    csv_escape "$log_path"; printf ','
    csv_escape "$command"; printf '\n'
  } >> "$RESULTS_CSV"

  printf '%-8s %-35s %s\n' "$status" "$test_id" "$reason"
}

render_summary() {
  : "${RESULTS_CSV:?RESULTS_CSV not set}"
  : "${SUMMARY_MD:?SUMMARY_MD not set}"
  local fail_count warn_count known_fail_count skip_count pass_count unknown_count
  fail_count=$(awk -F, 'NR>1 && $9 ~ /FAIL/ {c++} END{print c+0}' "$RESULTS_CSV")
  warn_count=$(awk -F, 'NR>1 && $9 ~ /WARN/ {c++} END{print c+0}' "$RESULTS_CSV")
  known_fail_count=$(awk -F, 'NR>1 && $9 ~ /KNOWN_FAIL/ {c++} END{print c+0}' "$RESULTS_CSV")
  skip_count=$(awk -F, 'NR>1 && $9 ~ /SKIP/ {c++} END{print c+0}' "$RESULTS_CSV")
  pass_count=$(awk -F, 'NR>1 && $9 ~ /PASS/ {c++} END{print c+0}' "$RESULTS_CSV")
  unknown_count=$(awk -F, 'NR>1 && $9 ~ /UNKNOWN/ {c++} END{print c+0}' "$RESULTS_CSV")

  local overall="PASS"
  if [ "$fail_count" -gt 0 ] || [ "$unknown_count" -gt 0 ]; then
    overall="FAIL"
  elif [ "$warn_count" -gt 0 ] || [ "$known_fail_count" -gt 0 ]; then
    overall="WARN"
  fi

  local commands_section
  commands_section=$(python3 - "$RESULTS_CSV" <<'PY'
import csv, sys
path = sys.argv[1]
with open(path, newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    if not reader.fieldnames or 'test_id' not in reader.fieldnames or 'command' not in reader.fieldnames:
        sys.exit(0)
    rows = []
    for row in reader:
        command = row.get('command') or ''
        if not command:
            continue
        test_id = row.get('test_id', '')
        rows.append(f"- `{test_id}`: `{command}`")
    if not rows:
        sys.exit(0)
    print('## Commands')
    print('\n'.join(rows))
PY
  ) || true

  cat > "$SUMMARY_MD" <<EOF2
# Cluster Acceptance Summary

- Run ID: \`$RUN_ID\`
- Cluster: \`$CLUSTER_NAME\`
- Scheduler: \`$SCHEDULER\`
- Overall: **$overall**

## Counts

| Status | Count |
|---|---:|
| PASS | $pass_count |
| FAIL | $fail_count |
| WARN | $warn_count |
| KNOWN_FAIL | $known_fail_count |
| SKIP | $skip_count |
| UNKNOWN | $unknown_count |

## Result file

- CSV: \`$RESULTS_CSV\`

EOF2

  if [ -n "$commands_section" ]; then
    printf '%s\n' "$commands_section" >> "$SUMMARY_MD"
  fi

  echo "Summary written to $SUMMARY_MD"
  [ "$overall" = "FAIL" ] && return 1
  return 0
}
