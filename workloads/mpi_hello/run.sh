#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
work="$RUN_DIR/work/mpi_hello"
mkdir -p "$work"
cp "$ROOT_DIR/workloads/mpi_hello/src/mpi_hello.c" "$work/"
logfile="$RUN_DIR/logs/mpi_hello.log"
job="$RUN_DIR/jobs/mpi_hello.${SCHEDULER}"

job_body="module purge >/dev/null 2>&1 || true
for m in $COMPILER_MODULES $MPI_MODULES; do module load \"\$m\"; done
cd \"$work\" || exit 1
$MPI_CC mpi_hello.c -o mpi_hello
mpiexec ./mpi_hello"

if [ "$SCHEDULER" = "pbs" ]; then
  create_pbs_job "mpi_hello" "$job_body" "$job" "$PBS_QUEUE" "$PBS_SELECT_MPI" "$DEFAULT_WALLTIME"
elif [ "$SCHEDULER" = "slurm" ]; then
  create_slurm_job "mpi_hello" "$job_body" "$job" "$SLURM_PARTITION" "$SLURM_MPI_NODES" "$SLURM_MPI_NTASKS"
else
  record_result "mpi_hello" "workload" "scheduler" "" "" "FAIL" "Unknown scheduler: $SCHEDULER" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "mpi_hello" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
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
if grep -q "MPI_HELLO" "$logfile" 2>/dev/null; then
  record_result "mpi_hello" "workload" "scheduler" "" "${job_id:-}" "PASS" "MPI job printed expected marker" "$started" "$ended" "" "$logfile"
else
  record_result "mpi_hello" "workload" "scheduler" "" "${job_id:-}" "FAIL" "MPI marker missing" "$started" "$ended" "" "$logfile"
fi
