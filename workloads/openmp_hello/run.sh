#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
work="$RUN_DIR/work/openmp_hello"
mkdir -p "$work"
cp "$ROOT_DIR/workloads/openmp_hello/src/openmp_hello.c" "$work/"
logfile="$RUN_DIR/logs/openmp_hello.log"
job="$RUN_DIR/jobs/openmp_hello.${SCHEDULER}"

job_body="module purge >/dev/null 2>&1 || true
for m in $COMPILER_MODULES; do module load \"\$m\"; done
cd \"$work\" || exit 1
export OMP_NUM_THREADS=4
$OPENMP_CC $OPENMP_CFLAGS openmp_hello.c -o openmp_hello
./openmp_hello"

if [ "$SCHEDULER" = "pbs" ]; then
  create_pbs_job "openmp_hello" "$job_body" "$job" "$PBS_QUEUE" "$PBS_SELECT_OPENMP" "$DEFAULT_WALLTIME"
elif [ "$SCHEDULER" = "slurm" ]; then
  # For OpenMP with SLURM, we need special handling for cpus-per-task
  cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=openmp_hello
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodes=$SLURM_OPENMP_NODES
#SBATCH --ntasks=$SLURM_OPENMP_NTASKS
#SBATCH --cpus-per-task=$SLURM_OPENMP_CPUS_PER_TASK
#SBATCH --mem=$DEFAULT_MEM
#SBATCH --time=$DEFAULT_TIME
#SBATCH --output=${job}.log
#SBATCH --error=${job}.err

cd "\$SLURM_SUBMIT_DIR" || exit 1

$job_body
EOF2
  chmod +x "$job"
else
  record_result "openmp_hello" "workload" "scheduler" "" "" "FAIL" "Unknown scheduler: $SCHEDULER" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "openmp_hello" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
  exit 0
fi

if [ "$SCHEDULER" = "pbs" ]; then
  job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err") || exit 1
  wait_job_pbs "$job_id" 1200 || exit 1
else
  job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err") || exit 1
  wait_job_slurm "$job_id" 1200 || exit 1
fi

ended=$(date '+%Y-%m-%dT%H:%M:%S')
if grep -q "OPENMP_HELLO" "$logfile" 2>/dev/null; then
  record_result "openmp_hello" "workload" "scheduler" "" "${job_id:-}" "PASS" "OpenMP job printed expected marker" "$started" "$ended" "" "$logfile"
else
  record_result "openmp_hello" "workload" "scheduler" "" "${job_id:-}" "FAIL" "OpenMP marker missing" "$started" "$ended" "" "$logfile"
fi
