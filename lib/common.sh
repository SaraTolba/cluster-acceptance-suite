#!/usr/bin/env bash
set -uo pipefail

suite_root() {
  local src="${BASH_SOURCE[0]}"
  while [ -h "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")/.." >/dev/null 2>&1 && pwd
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

load_cluster_config() {
  local cluster_key="$1"
  ROOT_DIR="${ROOT_DIR:-$(suite_root)}"
  CLUSTER_KEY="$cluster_key"
  CONFIG_FILE="$ROOT_DIR/config/clusters/${cluster_key}.env"
  [ -f "$CONFIG_FILE" ] || die "Cluster config not found: $CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  export ROOT_DIR CLUSTER_KEY CONFIG_FILE
  export CLUSTER_NAME SCHEDULER TEST_ACCOUNT
}

make_run_dir() {
  RUN_ID="${RUN_ID:-$(date '+%Y%m%d_%H%M%S')}"
  RUN_DIR="${RUN_DIR:-$ROOT_DIR/reports/$CLUSTER_NAME/$RUN_ID}"
  mkdir -p "$RUN_DIR" "$RUN_DIR/jobs" "$RUN_DIR/logs" "$RUN_DIR/work"
  export RUN_ID RUN_DIR
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

safe_name() {
  printf '%s' "$1" | tr '/: ' '___' | tr -cd 'A-Za-z0-9_.-'
}

trim() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
