#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

examples_file="$ROOT_DIR/$EXAMPLE_SET_FILE"
[ -f "$examples_file" ] || { record_result "examples_smoke" "workload" "examples" "" "" "FAIL" "Missing examples list: $examples_file" "" "" "" ""; exit 0; }

while IFS= read -r example; do
  example=$(printf '%s' "$example" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$example" ] && continue
  started=$(date '+%Y-%m-%dT%H:%M:%S')
  src_dir="$EXAMPLES_ROOT/$example"
  safe=$(safe_name "$example")
  logdir="$RUN_DIR/logs/examples/$safe"
  mkdir -p "$logdir"
  if [ ! -d "$src_dir" ]; then
    record_result "example:$example" "workload" "examples" "" "" "WARN" "example folder not found: $src_dir" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$logdir"
    continue
  fi

  if [ "$SCHEDULER" = "pbs" ]; then
    job_candidate=$(find "$src_dir" -maxdepth 2 -type f \( -name '*.pbs' -o -name '*pbs*' \) | head -n 1)
  else
    job_candidate=$(find "$src_dir" -maxdepth 2 -type f \( -name '*.slurm' -o -name '*.sbatch' -o -name '*slurm*' -o -name 'job.sh' \) | head -n 1)
  fi

  if [ -z "$job_candidate" ]; then
    record_result "example:$example" "workload" "examples" "" "" "WARN" "folder exists but no scheduler job script found" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$src_dir"
    continue
  fi

  if [ "${EXAMPLE_RUN_MODE:-discover}" != "submit" ] || [ "${DRY_RUN:-0}" = "1" ]; then
    record_result "example:$example" "workload" "examples" "" "" "PASS" "discovered job script: $job_candidate" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job_candidate"
    continue
  fi

  work="$RUN_DIR/work/examples/$safe"
  mkdir -p "$(dirname "$work")"
  cp -a "$src_dir" "$work"
  copied_job="$work/$(basename "$job_candidate")"
  if [ "$SCHEDULER" = "pbs" ]; then
    sed -i "s/^#PBS -W group_list=.*/#PBS -W group_list=$PBS_GROUP_LIST/" "$copied_job" || true
    sed -i "s/^#PBS -q .*/#PBS -q $PBS_QUEUE/" "$copied_job" || true
    job_id=$(cd "$work" && submit_job_pbs "$copied_job" 2> "$logdir/submit.err") && wait_job_pbs "$job_id" 3600
  else
    sed -i "s/^#SBATCH --account=.*/#SBATCH --account=$SLURM_ACCOUNT/" "$copied_job" || true
    sed -i "s/^#SBATCH --partition=.*/#SBATCH --partition=$SLURM_PARTITION/" "$copied_job" || true
    job_id=$(cd "$work" && submit_job_slurm "$copied_job" 2> "$logdir/submit.err") && wait_job_slurm "$job_id" 3600
  fi
  record_result "example:$example" "workload" "examples" "" "${job_id:-}" "UNKNOWN" "submitted example; review logs manually" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$work"
done < "$examples_file"
