#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
start_sec=$(date +%s)
job="$RUN_DIR/jobs/scheduler_basic.${SCHEDULER}"
logfile="$RUN_DIR/logs/scheduler_basic.log"

if [ "$SCHEDULER" = "pbs" ]; then
  cat > "$job" <<EOF2
#!/bin/bash
#PBS -N acc_basic
#PBS -q $PBS_QUEUE
#PBS -W group_list=$PBS_GROUP_LIST
#PBS -l select=$PBS_SELECT_BASIC
#PBS -l walltime=00:02:00
#PBS -j oe
#PBS -o $logfile
cd \$PBS_O_WORKDIR
hostname
date
ulimit -n
EOF2
elif [ "$SCHEDULER" = "slurm" ]; then
  cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=acc_basic
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=$DEFAULT_MEM
#SBATCH --time=00:02:00
#SBATCH --output=$logfile
#SBATCH --error=$logfile.err
cd \$SLURM_SUBMIT_DIR
hostname
date
ulimit -n
EOF2
else
  record_result "check_scheduler_basics" "sanity" "scheduler" "" "" "FAIL" "Unknown scheduler: $SCHEDULER" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi
chmod +x "$job"

if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "check_scheduler_basics" "sanity" "scheduler" "" "" "SKIP" "dry run; job generated at $job" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
  exit 0
fi

if [ "$SCHEDULER" = "pbs" ]; then
  job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err")
  submit_status=$?
  wait_job_pbs "$job_id" 300
  wait_status=$?
else
  job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err")
  submit_status=$?
  wait_job_slurm "$job_id" 300
  wait_status=$?
fi

ended=$(date '+%Y-%m-%dT%H:%M:%S')
end_sec=$(date +%s)
if [ "$submit_status" -ne 0 ]; then
  record_result "check_scheduler_basics" "sanity" "scheduler" "" "" "FAIL" "submit failed" "$started" "$ended" "$((end_sec-start_sec))" "$logfile.submit.err"
elif [ "$wait_status" -eq 124 ]; then
  record_result "check_scheduler_basics" "sanity" "scheduler" "" "$job_id" "FAIL" "job timed out waiting for completion" "$started" "$ended" "$((end_sec-start_sec))" "$logfile"
else
  record_result "check_scheduler_basics" "sanity" "scheduler" "" "$job_id" "PASS" "tiny scheduler job completed" "$started" "$ended" "$((end_sec-start_sec))" "$logfile"
fi
