#!/bin/bash

#######################################
# Description of the script:-
# to analyze job output files across multiple subdirectories, searching for specific error keywords and logging 
# job performance metrics. It creates a centralized CSV file containing information about potential errors and walltime for each job.
# Follow up manual work is requiered.
#
# Note the cones:- 
# - it assumes that each subdirectory has both output (.o) and error (.e) files.
# - it searches for error keywords in both output and error files, which can be missleading when the job calculate errors as part of the job. 
# - doesn't provide detailed error information, only whether an error keyword was found.
# - It assumes that job information is still available via qstat,
#
# Usage:-
# - Place this script in the parent directory containing subdirectories with job output files.
# - Ensure execute permissions: chmod +x script_name.sh
# - Run the script: ./script_name.sh
#
# Outputs:- all_jobs_errorlog.csv
#
# Sara Tolba, 10/07/2024
#######################################


# Define the parent directory and central log file
parent_dir="$PWD"
central_log_file="${parent_dir}/all_jobs_errorlog.csv"

# List of keywords to search for
keywords=("forrtl" "error" "severe" "failed" "exception" "illegal" "fault" "segmentation fault" "abort" "fatal" "Dependencies are missing")

# Initialize the central log file with headers
echo "JobName,walltime,walltime_seconds,error_exist" > ${central_log_file}

# Iterate through each subdirectory in the parent directory
for dir in "$parent_dir"/*; do
  if [ -d "$dir" ]; then
    cd "$dir" || continue  # Move to directory, continue if failed
    job_name="${dir##*/}"

    # Extract the job ID without the server name
    for job_file in "$job_name".o*[0-9]; do
    	echo "${job_file}"
      # Extract job ID from the file name
		job_id="${job_file##*.o}"  # Get the part after ".e"
		echo "Job ID: ${job_id}"

      # Define the output and error file paths: <job_name>.o<job_id>
        output_file="${dir}/${job_name}.o${job_id}"
        error_file="${dir}/${job_name}.e${job_id}"

      # Check for errors in the output and error files
      error_exist="NO"
      
      for keyword in "${keywords[@]}"; 
      do
        if grep -iq "$keyword" "$output_file" 2>/dev/null || grep -iq "$keyword" "$error_file" 2>/dev/null; then
          error_exist="YES"
        fi
      done


      # Log the resource usage information
      job_info=$(qstat -fx ${job_id})
      walltime=$(echo "${job_info}" | grep 'resources_used.walltime' | awk -F' = ' '{print $2}')
      walltime_seconds=$(echo $walltime | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')

      cpupercent=$(echo "${job_info}" | grep 'resources_used.cpupercent' | awk -F' = ' '{print $2}')
      cput =$(echo "${job_info}" | grep 'resources_used.cput' | awk -F' = ' '{print $2}')

      # Append job information to the central log file
      echo "${job_name},${walltime},${walltime_seconds},${error_exist}" >> ${central_log_file}
	echo "===================================================================="
    done

    cd "$parent_dir"  # Move back to parent directory
  fi
done

