#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/runners/run_sanity.sh"
source "$ROOT_DIR/runners/run_workloads.sh"

usage() {
  cat <<EOF2
Usage: $0 --cluster <cluster-key> [--mode all|sanity|workloads] [--dry-run] [--run-id ID]

Examples:
  $0 --cluster thunder-pbs --mode sanity
  $0 --cluster slurm-cluster --mode all --dry-run
EOF2
}

cluster=""
mode="all"
DRY_RUN="${DRY_RUN:-0}"
RUN_ID="${RUN_ID:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cluster) cluster="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$cluster" ] || { usage; exit 2; }
export DRY_RUN RUN_ID ROOT_DIR
load_cluster_config "$cluster"
make_run_dir
init_reporting

cat > "$RUN_DIR/metadata.txt" <<EOF2
run_id=$RUN_ID
cluster=$CLUSTER_NAME
scheduler=$SCHEDULER
config=$CONFIG_FILE
dry_run=$DRY_RUN
started_at=$(date '+%Y-%m-%dT%H:%M:%S')
EOF2

echo "Run directory: $RUN_DIR"
case "$mode" in
  sanity) run_sanity ;;
  workloads) run_workloads ;;
  all) run_sanity; run_workloads ;;
  *) die "Unknown mode: $mode" ;;
esac

render_summary
