#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

job_file="$1"
if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY_RUN: would submit $job_file"
  exit 0
fi

case "$SCHEDULER" in
  pbs) submit_job_pbs "$job_file" ;;
  slurm) submit_job_slurm "$job_file" ;;
  *) die "Unknown scheduler: $SCHEDULER" ;;
esac
