#!/bin/bash
# Create a temporary file to store module list
MODULE_LIST="module_list.txt"
# Get list of available modules
module -t avail 2>&1 | awk '!/^\// {print $1}' > "$MODULE_LIST"

# Create results directory with timestamp
RESULTS_DIR="results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Create the test job script - using "EOF" without quotes to allow variable expansion
cat > test_modules.pbs << EOF
#!/bin/bash
#PBS -q preemptible
#PBS -N module_test
#PBS -j oe
#PBS -l walltime=01:00:00
#PBS -W group_list=x-ccast-prj-khoang
##PBS -o ${RESULTS_DIR}

cd \$PBS_O_WORKDIR

# Read from the module list file in the working directory
while IFS= read -r module_name; do
    # Skip empty lines
    [ -z "\$module_name" ] && continue
    
    # Try to load the module and capture output
    output=\$(module load "\$module_name" 2>&1)
    
    # Check if module is unknown
    if echo "\$output" | grep -q "unknown" || echo "\$output" | grep -q "error"; then
        echo -e "\$module_name\t\t\$output\n\n"
    else
        module unload "\$module_name" 2>/dev/null
    fi
done < "\${PBS_O_WORKDIR}/${MODULE_LIST}"

EOF

# Submit jobs for each node
for node in $(freenodes -gco | tail -n +2 | awk '{print $1}'); do
    echo "Submitting test job for node: $node"
    qsub -l select=1:ncpus=1:mem=1gb:host=$node -N $node test_modules.pbs
done