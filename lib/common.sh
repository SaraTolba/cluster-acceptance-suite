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
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  set +a
  export ROOT_DIR CLUSTER_KEY CONFIG_FILE
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

validate_required_config_vars() {
  local required_vars
  local missing_vars=()
  
  case "${SCHEDULER:-}" in
    pbs)
      required_vars="CLUSTER_NAME SCHEDULER TEST_ACCOUNT PBS_QUEUE PBS_GROUP_LIST DEFAULT_WALLTIME PBS_SELECT_BASIC"
      ;;
    slurm)
      required_vars="CLUSTER_NAME SCHEDULER TEST_ACCOUNT SLURM_ACCOUNT SLURM_PARTITION DEFAULT_TIME"
      ;;
    *)
      die "SCHEDULER must be set to 'pbs' or 'slurm' in cluster config"
      ;;
  esac
  
  # Check common required vars
  required_vars="$required_vars COMPILER_MODULES MPI_MODULES OPENMP_CC MPI_CC"
  
  for var in $required_vars; do
    if [ -z "${!var:-}" ]; then
      missing_vars+=("$var")
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    die "Missing required config variables: ${missing_vars[*]}"
  fi
}

create_pbs_job() {
  local job_name="$1"
  local job_body="$2"
  local output_file="$3"
  local job_queue="${4:-$PBS_QUEUE}"
  local job_select="${5:-$PBS_SELECT_BASIC}"
  local job_walltime="${6:-$DEFAULT_WALLTIME}"
  
  cat > "$output_file" <<EOF2
#!/bin/bash
#PBS -N $job_name
#PBS -q $job_queue
#PBS -W group_list=$PBS_GROUP_LIST
#PBS -l select=$job_select
#PBS -l walltime=$job_walltime
#PBS -j oe
#PBS -o ${output_file}.log

cd "\$PBS_O_WORKDIR" || exit 1

$job_body
EOF2
  chmod +x "$output_file"
}

create_slurm_job() {
  local job_name="$1"
  local job_body="$2"
  local output_file="$3"
  local partition="${4:-$SLURM_PARTITION}"
  local nodes="${5:-1}"
  local ntasks="${6:-1}"
  local time="${7:-$DEFAULT_TIME}"
  
  cat > "$output_file" <<EOF2
#!/bin/bash
#SBATCH --job-name=$job_name
#SBATCH --partition=$partition
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodes=$nodes
#SBATCH --ntasks=$ntasks
#SBATCH --mem=$DEFAULT_MEM
#SBATCH --time=$time
#SBATCH --output=${output_file}.log
#SBATCH --error=${output_file}.err

cd "\$SLURM_SUBMIT_DIR" || exit 1

$job_body
EOF2
  chmod +x "$output_file"
}
