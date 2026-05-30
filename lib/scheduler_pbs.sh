#!/usr/bin/env bash

submit_job_pbs() {
  local job_file="$1"
  qsub "$job_file"
}

wait_job_pbs() {
  local job_id="$1"
  local timeout_sec="${2:-900}"
  local start now
  start=$(date +%s)
  while qstat "$job_id" >/dev/null 2>&1; do
    sleep 5
    now=$(date +%s)
    if [ $((now - start)) -gt "$timeout_sec" ]; then
      return 124
    fi
  done
  return 0
}

cancel_job_pbs() {
  qdel "$1" >/dev/null 2>&1 || true
}
