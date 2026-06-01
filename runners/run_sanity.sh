#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

run_sanity() {
  local tests=(
    "$ROOT_DIR/sanity/check_env_vars.sh"
    "$ROOT_DIR/sanity/check_ulimits.sh"
    "$ROOT_DIR/sanity/check_filesystems.sh"
    "$ROOT_DIR/sanity/check_modules_avail.sh"
    "$ROOT_DIR/sanity/check_required_modules.sh"
    "$ROOT_DIR/sanity/check_module_dependencies.sh"
    "$ROOT_DIR/sanity/check_scheduler_basics.sh"
  )
  for t in "${tests[@]}"; do
    echo "Running $(basename "$t")"
    CURRENT_COMMAND="bash $t" bash "$t" || true
  done
  if [ "${RUN_NODE_MODULE_CHECK:-0}" = "1" ]; then
    bash "$ROOT_DIR/sanity/check_module_loads_per_node.sh" || true
  fi
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
  run_sanity
  render_summary || true
fi
