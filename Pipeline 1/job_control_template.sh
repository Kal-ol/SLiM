#!/usr/bin/env bash
set -euo pipefail

model="${1:?Expected the path to the SLiM model}"
output_root="${2:?Expected the output directory}"
rep="${SLURM_ARRAY_TASK_ID:?Run this script as a Slurm array task}"
job="${SLURM_ARRAY_JOB_ID:?Run this script as a Slurm array task}"
seed=$((67000000 + rep))

# Example treatment. Ticks 1–2000 are burn-in; 2001–4000 are secondary contact.
burnin=2000
end_gen=4000
scenario=theta1
hyb_rate=0.10

# Give each job and replicate its own output directory.
out="$output_root/job_${job}/rep_${rep}"
mkdir -p "$out"
cd "$out"

module load slim/4.3

# Start from fresh populations and run both phases in one SLiM invocation.
slim -s "$seed" \
    -d "burnin=$burnin" \
    -d "endGen=$end_gen" \
    -d 'sectionStart=0' \
    -d "sectionEnd=$end_gen" \
    -d "envScenario=\"$scenario\"" \
    -d "hybRate=$hyb_rate" \
    -d 'recordTreeSeq=F' \
    -d 'writeFinalTree=F' \
    -d 'writeFinalCheckpoint=F' \
    -d 'outputFile="per_generation.csv"' \
    "$model" > slim_console.txt 2>&1
