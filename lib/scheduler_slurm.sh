#!/usr/bin/env bash

submit_job_slurm() {
  local job_file="$1"
  sbatch --parsable "$job_file"
}

wait_job_slurm() {
  local job_id="$1"
  local timeout_sec="${2:-900}"
  local start now
  start=$(date +%s)
  while squeue -j "$job_id" -h >/dev/null 2>&1 && [ -n "$(squeue -j "$job_id" -h 2>/dev/null)" ]; do
    sleep 5
    now=$(date +%s)
    if [ $((now - start)) -gt "$timeout_sec" ]; then
      return 124
    fi
  done
  return 0
}

cancel_job_slurm() {
  scancel "$1" >/dev/null 2>&1 || true
}
