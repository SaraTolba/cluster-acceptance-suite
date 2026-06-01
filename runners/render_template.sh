#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 TEMPLATE OUTFILE TEST_BODY_FILE" >&2
  exit 2
fi

template="$1"
outfile="$2"
body_file="$3"

tmp="${outfile}.tmp"
awk -v body="$body_file" '
  /\{\{TEST_BODY\}\}/ {
    while ((getline line < body) > 0) print line
    close(body)
    next
  }
  {print}
' "$template" > "$tmp"

vars="JOB_NAME PBS_QUEUE PBS_GROUP_LIST PBS_SELECT PBS_SELECT_GPU WALLTIME LOG_FILE ERR_FILE CLUSTER_NAME SLURM_PARTITION SLURM_ACCOUNT NODES NTASKS NTASKS_PER_NODE CPUS_PER_TASK MEM TIME"
for var in $vars; do
  val="${!var:-}"
  esc=$(printf '%s' "$val" | sed 's/[&/]/\\&/g')
  sed -i "s/{{$var}}/$esc/g" "$tmp"
done

mv "$tmp" "$outfile"
chmod +x "$outfile"
