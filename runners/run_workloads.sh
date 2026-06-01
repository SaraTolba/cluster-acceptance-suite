#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

run_workloads() {
  local tests=(
    "$ROOT_DIR/workloads/mpi_hello/run.sh"
    "$ROOT_DIR/workloads/openmp_hello/run.sh"
    "$ROOT_DIR/workloads/hybrid_mpi_openmp/run.sh"
    "$ROOT_DIR/workloads/module_heavy_smoke/run.sh"
    "$ROOT_DIR/workloads/examples_smoke/run.sh"
  )
  for t in "${tests[@]}"; do
    echo "Running $(dirname "$t" | xargs basename)"
    CURRENT_COMMAND="bash $t" bash "$t" || true
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cluster=""
  DRY_RUN="${DRY_RUN:-0}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --cluster) cluster="$2"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  done
  [ -n "$cluster" ] || die "Use --cluster <cluster-key>"
  export DRY_RUN
  load_cluster_config "$cluster"
  make_run_dir
  init_reporting
  run_workloads
  render_summary || true
fi
