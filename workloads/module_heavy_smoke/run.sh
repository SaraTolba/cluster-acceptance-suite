#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
logfile="$RUN_DIR/logs/module_heavy_smoke.log"
job="$RUN_DIR/jobs/module_heavy_smoke.${SCHEDULER}"

body='module purge >/dev/null 2>&1 || true
failed=0
for m in '"$MODULE_HEAVY_STACK"'; do
  echo "Loading $m"
  if ! module load "$m"; then
    echo "FAILED $m"
    failed=1
  fi
done
module list
python --version 2>/dev/null || true
exit $failed'

if [ "$SCHEDULER" = "pbs" ]; then
  create_pbs_job "module_heavy" "$body" "$job" "$PBS_QUEUE" "$PBS_SELECT_BASIC" "$DEFAULT_WALLTIME"
elif [ "$SCHEDULER" = "slurm" ]; then
  create_slurm_job "module_heavy" "$body" "$job" "$SLURM_PARTITION" "1" "1"
else
  record_result "module_heavy_smoke" "workload" "scheduler" "" "" "FAIL" "Unknown scheduler: $SCHEDULER" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "module_heavy_smoke" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
  exit 0
fi
if [ "$SCHEDULER" = "pbs" ]; then
  job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err") || exit 1
  wait_job_pbs "$job_id" 900 || exit 1
else
  job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err") || exit 1
  wait_job_slurm "$job_id" 900 || exit 1
fi
ended=$(date '+%Y-%m-%dT%H:%M:%S')
if grep -q "FAILED" "$logfile" 2>/dev/null; then
  record_result "module_heavy_smoke" "workload" "scheduler" "" "${job_id:-}" "FAIL" "one or more modules failed in heavy stack" "$started" "$ended" "" "$logfile"
else
  record_result "module_heavy_smoke" "workload" "scheduler" "" "${job_id:-}" "PASS" "module heavy stack loaded" "$started" "$ended" "" "$logfile"
fi
