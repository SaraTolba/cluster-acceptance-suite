#!/bin/bash
for NODE1 in $(freenodes | tail -n +2 | awk '{print $1}'); do
	for NODE2 in $(freenodes | tail -n +2 | awk '{print $1}'); do
		if [ "$NODE1" == "$NODE2" ]; then
			continue
		else
    		qsub -l select=1:ncpus=4:mpiprocs=2:ompthreads=2:mem=2gb:host=$NODE1+1:ncpus=4:mpiprocs=2:ompthreads=2:mem=2gb:host=$NODE2 -N ${NODE1}-${NODE2}.test ./test-nodes.pbs
		fi
	done
done