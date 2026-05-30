#!/bin/bash

for NODE in $(freenodes | tail -n +2 | awk '{print $1}'); do
    qsub -l select=1:ncpus=1:mem=1gb:host=$NODE -N ${NODE}.test ./job.pbs
done