#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"

if [ -z "${RUN_DIR:-}" ]; then
  echo "Set RUN_DIR to an existing report directory." >&2
  exit 2
fi
RESULTS_CSV="$RUN_DIR/acceptance_results.csv"
SUMMARY_MD="$RUN_DIR/acceptance_summary.md"
render_summary
