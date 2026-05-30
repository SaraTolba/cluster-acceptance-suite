#!/bin/bash
# Output file
OUTPUT_FILE="module_show.txt"
> $OUTPUT_FILE  # Clear the file

# Get list of available modules
# module_list=$(module -t avail 2>&1 | awk '!/^\// {print $1}' | sort -f)
module_list=$(module -t --redirect avail | sort -f)



# Check each module
for mod in $module_list; do
    echo "#==== MODULE: $mod ====#" >> $OUTPUT_FILE
    module show $mod 2>&1 &>> $OUTPUT_FILE
    echo -e "\n\n" >> $OUTPUT_FILE
done