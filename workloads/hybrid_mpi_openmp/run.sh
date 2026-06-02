#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
work="$RUN_DIR/work/hybrid_mpi_openmp"
mkdir -p "$work"
cp "$ROOT_DIR/workloads/hybrid_mpi_openmp/src/hybrid_hello.c" "$work/"
logfile="$RUN_DIR/logs/hybrid_mpi_openmp.log"
job="$RUN_DIR/jobs/hybrid_mpi_openmp.${SCHEDULER}"

job_body="module purge >/dev/null 2>&1 || true
for m in $COMPILER_MODULES $MPI_MODULES; do module load \"\$m\"; done
cd \"$work\" || exit 1
export OMP_NUM_THREADS=2
$MPI_CC $HYBRID_CFLAGS hybrid_hello.c -o hybrid_hello
mpiexec ./hybrid_hello"

if [ "$SCHEDULER" = "pbs" ]; then
  create_pbs_job "hybrid_hello" "$job_body" "$job" "$PBS_QUEUE" "$PBS_SELECT_HYBRID" "$DEFAULT_WALLTIME"
elif [ "$SCHEDULER" = "slurm" ]; then
  # For hybrid with SLURM, we need special handling for cpus-per-task
  cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=hybrid_hello
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodes=$SLURM_HYBRID_NODES
#SBATCH --ntasks=$SLURM_HYBRID_NTASKS
#SBATCH --ntasks-per-node=$SLURM_HYBRID_TASKS_PER_NODE
#SBATCH --cpus-per-task=$SLURM_HYBRID_CPUS_PER_TASK
#SBATCH --mem=$DEFAULT_MEM
#SBATCH --time=$DEFAULT_TIME
#SBATCH --output=${job}.log
#SBATCH --error=${job}.err

cd "\$SLURM_SUBMIT_DIR" || exit 1

$job_body
EOF2
  chmod +x "$job"
else
  record_result "hybrid_mpi_openmp" "workload" "scheduler" "" "" "FAIL" "Unknown scheduler: $SCHEDULER" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" ""
  exit 0
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "hybrid_mpi_openmp" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
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
if grep -q "HYBRID_HELLO" "$logfile" 2>/dev/null; then
  record_result "hybrid_mpi_openmp" "workload" "scheduler" "" "${job_id:-}" "PASS" "Hybrid job printed expected marker" "$started" "$ended" "" "$logfile"
else
  record_result "hybrid_mpi_openmp" "workload" "scheduler" "" "${job_id:-}" "FAIL" "Hybrid marker missing" "$started" "$ended" "" "$logfile"
fi
