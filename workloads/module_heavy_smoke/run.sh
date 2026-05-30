#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

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
  cat > "$job" <<EOF2
#!/bin/bash
#PBS -N module_heavy
#PBS -q $PBS_QUEUE
#PBS -W group_list=$PBS_GROUP_LIST
#PBS -l select=$PBS_SELECT_BASIC
#PBS -l walltime=$DEFAULT_WALLTIME
#PBS -j oe
#PBS -o $logfile
$body
EOF2
else
  cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=module_heavy
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=$DEFAULT_MEM
#SBATCH --time=$DEFAULT_TIME
#SBATCH --output=$logfile
#SBATCH --error=$logfile.err
$body
EOF2
fi
chmod +x "$job"
if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "module_heavy_smoke" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
  exit 0
fi
if [ "$SCHEDULER" = "pbs" ]; then
  job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err") && wait_job_pbs "$job_id" 900
else
  job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err") && wait_job_slurm "$job_id" 900
fi
ended=$(date '+%Y-%m-%dT%H:%M:%S')
if grep -q "FAILED" "$logfile" 2>/dev/null; then
  record_result "module_heavy_smoke" "workload" "scheduler" "" "${job_id:-}" "FAIL" "one or more modules failed in heavy stack" "$started" "$ended" "" "$logfile"
else
  record_result "module_heavy_smoke" "workload" "scheduler" "" "${job_id:-}" "PASS" "module heavy stack loaded" "$started" "$ended" "" "$logfile"
fi
