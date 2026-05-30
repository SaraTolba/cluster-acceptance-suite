#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

started=$(date '+%Y-%m-%dT%H:%M:%S')
work="$RUN_DIR/work/openmp_hello"
mkdir -p "$work"
cp "$ROOT_DIR/workloads/openmp_hello/src/openmp_hello.c" "$work/"
logfile="$RUN_DIR/logs/openmp_hello.log"
job="$RUN_DIR/jobs/openmp_hello.${SCHEDULER}"

if [ "$SCHEDULER" = "pbs" ]; then
  cat > "$job" <<EOF2
#!/bin/bash
#PBS -N openmp_hello
#PBS -q $PBS_QUEUE
#PBS -W group_list=$PBS_GROUP_LIST
#PBS -l select=$PBS_SELECT_OPENMP
#PBS -l walltime=$DEFAULT_WALLTIME
#PBS -j oe
#PBS -o $logfile
cd "$work" || exit 1
module purge >/dev/null 2>&1 || true
for m in $COMPILER_MODULES; do module load "\$m"; done
export OMP_NUM_THREADS=4
$OPENMP_CC $OPENMP_CFLAGS openmp_hello.c -o openmp_hello
./openmp_hello
EOF2
else
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
#SBATCH --output=$logfile
#SBATCH --error=$logfile.err
cd "$work" || exit 1
module purge >/dev/null 2>&1 || true
for m in $COMPILER_MODULES; do module load "\$m"; done
export OMP_NUM_THREADS=$SLURM_OPENMP_CPUS_PER_TASK
$OPENMP_CC $OPENMP_CFLAGS openmp_hello.c -o openmp_hello
./openmp_hello
EOF2
fi
chmod +x "$job"
if [ "${DRY_RUN:-0}" = "1" ]; then
  record_result "openmp_hello" "workload" "scheduler" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
  exit 0
fi
if [ "$SCHEDULER" = "pbs" ]; then
  job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err") && wait_job_pbs "$job_id" 1200
else
  job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err") && wait_job_slurm "$job_id" 1200
fi
ended=$(date '+%Y-%m-%dT%H:%M:%S')
if grep -q "OPENMP_HELLO" "$logfile" 2>/dev/null; then
  record_result "openmp_hello" "workload" "scheduler" "" "${job_id:-}" "PASS" "OpenMP job printed expected marker" "$started" "$ended" "" "$logfile"
else
  record_result "openmp_hello" "workload" "scheduler" "" "${job_id:-}" "FAIL" "OpenMP marker missing" "$started" "$ended" "" "$logfile"
fi
