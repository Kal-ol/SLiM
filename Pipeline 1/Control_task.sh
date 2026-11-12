#!/usr/bin/env bash
set -euo pipefail

config=${1:?Expected CONFIG.yaml}
# Slurm may spool this script elsewhere, so the launcher passes the helper path.
here=${2:?Submit this worker with submit_full_run.sh}
task=${SLURM_ARRAY_TASK_ID:?Expected Slurm array task ID}
job=${SLURM_ARRAY_JOB_ID:?Expected Slurm array job ID}

settings=$(python3 "$here/full_run_config.py" task "$config" "$task")
mapfile -t values <<< "$settings"
model=${values[0]}
out="${values[1]}/job_${job}/task_${task}_rep_${values[3]}"
seed=${values[4]}

mkdir -p "$(dirname "$out")"
mkdir "$out"
cp "$config" "$out/config_used.yaml"

module load "${values[2]}"
args=()
for value in "${values[@]:5}"; do
    args+=(-d "$value")
done

cd "$out"
printf '%q ' slim -s "$seed" "${args[@]}" "$model" > command_used.txt
printf '\n' >> command_used.txt
slim -s "$seed" "${args[@]}" "$model" > slim_console.txt 2>&1
