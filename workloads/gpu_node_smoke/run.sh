#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

GPU_NODE_LIST="${GPU_NODE_LIST:-}"
GPU_QUEUE="${GPU_QUEUE:-gpus}"
GPU_JOB_TIME="${GPU_JOB_TIME:-00:05:00}"
GPU_JOB_NCPUS="${GPU_JOB_NCPUS:-2}"
GPU_JOB_MEM="${GPU_JOB_MEM:-5gb}"
GPU_JOB_NGPUS="${GPU_JOB_NGPUS:-1}"

run_gpu_node_smoke() {
  if [ -z "$GPU_NODE_LIST" ]; then
    die "GPU node smoke workload requires GPU_NODE_LIST to be set in the cluster config."
  fi
  for node in $GPU_NODE_LIST; do
    started=$(date '+%Y-%m-%dT%H:%M:%S')
    safe=$(safe_name "$node")
    work="$RUN_DIR/work/gpu_node_smoke/$safe"
    mkdir -p "$work"
    logfile="$RUN_DIR/logs/gpu_node_smoke_${safe}.log"
    job="$RUN_DIR/jobs/gpu_node_smoke_${safe}.${SCHEDULER}"

    if [ "$SCHEDULER" = "pbs" ]; then
      cat > "$job" <<EOF2
#!/bin/bash
#PBS -N gpu-test-${node}
#PBS -q $GPU_QUEUE
#PBS -l select=1:ncpus=$GPU_JOB_NCPUS:mem=$GPU_JOB_MEM:ngpus=$GPU_JOB_NGPUS:host=${node}
#PBS -l walltime=$GPU_JOB_TIME
#PBS -o $logfile
#PBS -e ${logfile}.err
#PBS -W group_list=$PBS_GROUP_LIST
cd "\$PBS_O_WORKDIR" || exit 1
module purge >/dev/null 2>&1 || true
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not available"
  exit 2
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
exit 0
EOF2
    else
      cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=gpu-test-${node}
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodelist=${node}
#SBATCH --gres=gpu:${GPU_JOB_NGPUS}
#SBATCH --cpus-per-task=${GPU_JOB_NCPUS}
#SBATCH --mem=${GPU_JOB_MEM}
#SBATCH --time=${GPU_JOB_TIME}
#SBATCH --output=$logfile
#SBATCH --error=${logfile}.err
cd "\$SLURM_SUBMIT_DIR" || exit 1
module purge >/dev/null 2>&1 || true
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not available"
  exit 2
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
exit 0
EOF2
    fi

    chmod +x "$job"
    if [ "${DRY_RUN:-0}" = "1" ]; then
      record_result "gpu_node_smoke:${node}" "workload" "gpu_node" "" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
      continue
    fi

    if [ "$SCHEDULER" = "pbs" ]; then
      job_id=$(submit_job_pbs "$job" 2> "${logfile}.submit.err")
      wait_exit=0
      if [ -n "${job_id:-}" ]; then
        wait_job_pbs "$job_id" 1200 || wait_exit=$?
      else
        wait_exit=255
      fi
    else
      job_id=$(submit_job_slurm "$job" 2> "${logfile}.submit.err")
      wait_exit=0
      if [ -n "${job_id:-}" ]; then
        wait_job_slurm "$job_id" 1200 || wait_exit=$?
      else
        wait_exit=255
      fi
    fi

    ended=$(date '+%Y-%m-%dT%H:%M:%S')
    if [ -z "${job_id:-}" ]; then
      record_result "gpu_node_smoke:${node}" "workload" "gpu_node" "" "" "FAIL" "submission failed; see ${logfile}.submit.err" "$started" "$ended" "" "$logfile"
      continue
    fi
    if [ "$wait_exit" -ne 0 ]; then
      record_result "gpu_node_smoke:${node}" "workload" "gpu_node" "" "$job_id" "FAIL" "job wait failed with exit $wait_exit" "$started" "$ended" "" "$logfile"
      continue
    fi
    if grep -q "driver_version" "$logfile" 2>/dev/null; then
      record_result "gpu_node_smoke:${node}" "workload" "gpu_node" "" "$job_id" "PASS" "gpu info collected" "$started" "$ended" "" "$logfile"
    else
      record_result "gpu_node_smoke:${node}" "workload" "gpu_node" "" "$job_id" "FAIL" "gpu info missing from log" "$started" "$ended" "" "$logfile"
    fi
  done
}

run_gpu_node_smoke
