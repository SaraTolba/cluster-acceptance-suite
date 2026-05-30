#!/bin/bash
# Output file
OUTPUT_FILE="modules_depends_on_openmpi_mlnx_gcc_64.txt"

> $OUTPUT_FILE

# Get list of available modules
# module_list=$(module -t avail 2>&1 | awk '!/^\// {print $1}' | sort -f)
module_list=$(module -t --redirect avail | sort -f)


# Add header to output file
echo -e "module\t\t\t depends on?" >> $OUTPUT_FILE

# Check each module
for mod in $module_list; do
    if module show $mod 2>&1 | grep -q "openmpi/mlnx/gcc/64"; then
        echo -e "$mod\t\t\tYES" >> $OUTPUT_FILE
    else
        echo -e "$mod\t\t\tno" >> $OUTPUT_FILE
    fi
done

echo "Finished checking modules. Results saved to $OUTPUT_FILE"



