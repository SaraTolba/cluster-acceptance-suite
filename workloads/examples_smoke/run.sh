#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

error_keywords=("forrtl" "error" "severe" "failed" "exception" "illegal" "fault" "segmentation fault" "abort" "fatal" "Dependencies are missing")

collect_job_log_files() {
  local job_id="$1"
  local work_dir="$2"
  local path
  local -a paths=()

  if [ "$SCHEDULER" = "pbs" ] && [ -n "$job_id" ] && command_exists qstat; then
    if qstat_out=$(qstat -fx "$job_id" 2>/dev/null); then
      while IFS= read -r line; do
        case "$line" in
          *Output_Path*=*) paths+=("$(printf '%s' "$line" | awk -F' = ' '{print $2}')") ;;
          *Error_Path*=*) paths+=("$(printf '%s' "$line" | awk -F' = ' '{print $2}')") ;;
        esac
      done <<< "$qstat_out"
    fi
  elif [ "$SCHEDULER" = "slurm" ] && [ -n "$job_id" ] && command_exists scontrol; then
    if scontrol_out=$(scontrol show jobid "$job_id" 2>/dev/null); then
      while IFS= read -r line; do
        case "$line" in
          *StdOutPath=*) paths+=("$(printf '%s' "$line" | awk -F'=' '{print $2}')") ;;
          *StdErrPath=*) paths+=("$(printf '%s' "$line" | awk -F'=' '{print $2}')") ;;
        esac
      done <<< "$scontrol_out"
    fi
  fi

  while IFS= read -r -d '' path; do
    paths+=("$path")
  done < <(find "$work_dir" -type f \( -name '*.o*' -o -name '*.e*' -o -name '*.out' -o -name '*.err' -o -name 'slurm-*.out' \) -print0 2>/dev/null)

  declare -A seen
  for path in "${paths[@]}"; do
    [ -n "$path" ] || continue
    if [ -f "$path" ] && [ -z "${seen[$path]:-}" ]; then
      printf '%s\n' "$path"
      seen[$path]=1
    fi
  done
}

scan_job_logs_for_errors() {
  local job_id="$1"
  local work_dir="$2"
  local file keyword
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    for keyword in "${error_keywords[@]}"; do
      if grep -iq -- "$keyword" "$file" 2>/dev/null; then
        printf '%s:%s\n' "$keyword" "$file"
        return 0
      fi
    done
  done < <(collect_job_log_files "$job_id" "$work_dir")
  return 1
}

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
    job_id=$(cd "$work" && submit_job_pbs "$copied_job" 2> "$logdir/submit.err")
    wait_exit=0
    if [ -n "$job_id" ]; then
      wait_job_pbs "$job_id" 3600 || wait_exit=$?
    else
      wait_exit=255
    fi
  else
    sed -i "s/^#SBATCH --account=.*/#SBATCH --account=$SLURM_ACCOUNT/" "$copied_job" || true
    sed -i "s/^#SBATCH --partition=.*/#SBATCH --partition=$SLURM_PARTITION/" "$copied_job" || true
    job_id=$(cd "$work" && submit_job_slurm "$copied_job" 2> "$logdir/submit.err")
    wait_exit=0
    if [ -n "$job_id" ]; then
      wait_job_slurm "$job_id" 3600 || wait_exit=$?
    else
      wait_exit=255
    fi
  fi

  if [ -z "${job_id:-}" ]; then
    record_result "example:$example" "workload" "examples" "" "" "FAIL" "example submission failed; see $logdir/submit.err" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$logdir" ""
    continue
  fi

  if [ "$wait_exit" -ne 0 ]; then
    record_result "example:$example" "workload" "examples" "" "$job_id" "FAIL" "job did not complete successfully; wait exit $wait_exit; see $logdir/submit.err" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$logdir" ""
    continue
  fi

  error_line=""
  if error_line=$(scan_job_logs_for_errors "$job_id" "$work" 2>/dev/null); then
    record_result "example:$example" "workload" "examples" "" "$job_id" "FAIL" "error keyword found in output: $error_line" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$work" ""
    continue
  fi

  if [ -z "$(collect_job_log_files "$job_id" "$work")" ]; then
    record_result "example:$example" "workload" "examples" "" "$job_id" "WARN" "job completed but no output/error files were found" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$work" ""
    continue
  fi

  record_result "example:$example" "workload" "examples" "" "$job_id" "PASS" "job completed without matching error keywords" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "" "$work" ""
done < "$examples_file"
