#!/usr/bin/env bash
set -u
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/reporting.sh"
source "$ROOT_DIR/lib/scheduler_pbs.sh"
source "$ROOT_DIR/lib/scheduler_slurm.sh"

required_file="$ROOT_DIR/$REQUIRED_MODULES_FILE"
[ -f "$required_file" ] || { record_result "check_module_loads_per_node" "sanity" "nodes" "" "" "FAIL" "Missing required modules file" "" "" "" ""; exit 0; }

nodes=$(eval "$NODE_DISCOVERY_COMMAND" 2>/dev/null | awk 'NF {print $1}')
if [ "${NODE_SCOPE:-sample}" = "sample" ]; then
  nodes=$(printf '%s\n' "$nodes" | head -n "${NODE_SAMPLE_COUNT:-4}")
fi

if [ -z "$nodes" ]; then
  record_result "check_module_loads_per_node" "sanity" "nodes" "" "" "WARN" "No nodes discovered" "" "" "" ""
  exit 0
fi

for node in $nodes; do
  started=$(date '+%Y-%m-%dT%H:%M:%S')
  job="$RUN_DIR/jobs/module_node_${node}.${SCHEDULER}"
  logfile="$RUN_DIR/logs/module_node_${node}.log"
  body="$RUN_DIR/jobs/module_node_${node}.body.sh"
  cat > "$body" <<EOF2
failed=0
while IFS= read -r mod; do
  mod=\$(echo "\$mod" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*\$//')
  [ -z "\$mod" ] && continue
  echo "Loading module: \$mod"
  if ! module load "\$mod"; then
    echo "FAILED module: \$mod"
    failed=1
  fi
  module purge >/dev/null 2>&1 || true
done < "$required_file"
exit \$failed
EOF2
  if [ "$SCHEDULER" = "pbs" ]; then
    cat > "$job" <<EOF2
#!/bin/bash
#PBS -N mod_${node}
#PBS -q $PBS_QUEUE
#PBS -W group_list=$PBS_GROUP_LIST
#PBS -l select=1:ncpus=1:mem=1gb:host=$node
#PBS -l walltime=00:10:00
#PBS -j oe
#PBS -o $logfile
cd \$PBS_O_WORKDIR
source "$body"
EOF2
  else
    cat > "$job" <<EOF2
#!/bin/bash
#SBATCH --job-name=mod_${node}
#SBATCH --partition=$SLURM_PARTITION
#SBATCH --account=$SLURM_ACCOUNT
#SBATCH --nodelist=$node
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=$logfile
#SBATCH --error=$logfile.err
cd \$SLURM_SUBMIT_DIR
source "$body"
EOF2
  fi
  chmod +x "$job"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    record_result "module_loads_node:$node" "sanity" "node" "$node" "" "SKIP" "dry run; job generated" "$started" "$(date '+%Y-%m-%dT%H:%M:%S')" "0" "$job"
    continue
  fi
  if [ "$SCHEDULER" = "pbs" ]; then
    job_id=$(submit_job_pbs "$job" 2> "$logfile.submit.err") && wait_job_pbs "$job_id" 900
  else
    job_id=$(submit_job_slurm "$job" 2> "$logfile.submit.err") && wait_job_slurm "$job_id" 900
  fi
  ended=$(date '+%Y-%m-%dT%H:%M:%S')
  if grep -q "FAILED module" "$logfile" 2>/dev/null; then
    record_result "module_loads_node:$node" "sanity" "node" "$node" "${job_id:-}" "FAIL" "one or more required modules failed" "$started" "$ended" "" "$logfile"
  else
    record_result "module_loads_node:$node" "sanity" "node" "$node" "${job_id:-}" "PASS" "required modules loaded" "$started" "$ended" "" "$logfile"
  fi
done
