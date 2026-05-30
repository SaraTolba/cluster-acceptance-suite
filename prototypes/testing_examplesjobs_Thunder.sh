#!/bin/bash

# Define the parent directory and central log file
parent_dir="$PWD"
central_log_file="${parent_dir}/all_jobs_log.csv"
All_job_ids="${parent_dir}/All_job_ids.txt"

# Initialize the central log file with headers
echo "JobID,JobName,StartTime,RunTime,Memory,CPUPercent" > ${central_log_file}
echo "JobID" > ${All_job_ids}

# Iterate through each subdirectory in the parent directory
for dir in "$parent_dir"/*; do
  if [ -d "$dir" ]; then
    cd "$dir" || continue  # Move to directory, continue if failed
    job_name="${dir##*/}"

    echo "================" "$job_name" "================" 

    # Find the .pbs file in the directory
    pbs_files=( *.pbs )
    if [ ${#pbs_files[@]} -eq 0 ]; then
      echo "No .pbs files found in $dir, skipping."
      cd "$parent_dir"
      continue
    fi

    for pbs_file in "${pbs_files[@]}"; do
      # Make the changes to the .pbs file
      sed -i '/^#PBS -W group_list=x-ccast-prj/s/.*/#PBS -W group_list=x-ccast-prj-khoang/' "$pbs_file"
      sed -i '/^#PBS -q/s/.*/#PBS -q preemptible/' "$pbs_file"
      sed -i "/^#PBS -N/s/.*/#PBS -N $job_name/" "$pbs_file"
      # sed -i '/^#PBS -l select=1:/ s/$/:host=node0065/' "$pbs_file"
      sed -i '/#PBS -W group_list/a # Log job start time\nstart_time=$(date "+%a %b %d %H:%M:%S %Y")' "$pbs_file"
      sed -i '/exit 0/d' "$pbs_file"

      # Append job log information before the "exit 0" line
      cat >> "$pbs_file" << EOF

# Log job end time
end_time=\$(date "+%a %b %d %H:%M:%S %Y")

log_file="${job_name}_log.out"

echo "Job ID: \${PBS_JOBID}" >> \${log_file}

# Log actual printing time to compare stime
echo "Job started printing output: \${start_time}" >> \${log_file}

# Calculate actual running time
runtime=\$((\$(date -d "\$end_time" +%s) - \$(date -d "\$start_time" +%s)))

# Log the end of job details
echo "Total runtime: \$runtime seconds" >> \${log_file}

# Wait for a few seconds to ensure the job information is updated
sleep 20

# Log the resource usage information
job_info=\$(qstat -fx \${PBS_JOBID})
mem=\$(echo "\${job_info}" | grep 'resources_used.mem' | awk -F' = ' '{print \$2}')
cpupercent=\$(echo "\${job_info}" | grep 'resources_used.cpupercent' | awk -F' = ' '{print \$2}')


echo "Resources Used:" >> \${log_file}
echo "Memory: \${mem}" >> \${log_file}
echo "CPU Percent: \${cpupercent}" >> \${log_file}


# Append job information to the central log file
echo "\${PBS_JOBID},${job_name},\${start_time},\${runtime},\${mem},\${cpupercent}" >> ${central_log_file}
echo "\${PBS_JOBID}" >> ${All_job_ids}


exit 0

EOF

      # Define the logfile name
#       sed -i "/cd \$PBS_O_WORKDIR/a log_file=\"${job_name}_log.out\"" "$pbs_file"
        
      # Check if qsub was successful before proceeding
      qsub "$pbs_file" || { echo "Failed to submit job: $pbs_file"; continue; }
    done
    cd "$parent_dir"  # Move back to parent directory
  fi
done



