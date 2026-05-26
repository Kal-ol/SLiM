#!/bin/bash
#SBATCH --partition=kingspeak
#SBATCH --job-name=slim_reps
#SBATCH --time=72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=20G
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: sbatch run_kingspeak_100reps.sh <hyb|sb|alpha|sigma|recomb|mut>"
    exit 1
fi

module load slim/4.3

cd "$HOME/slim_runs/scripts"
mkdir -p "$HOME/slim_runs/logs"

SWEEP="$1"

# max = number of SLiM runs to run at once
max=10

# total = total number of replicate runs
total=100

count=0

echo "Running sweep=${SWEEP}"
echo "Total replicates=${total}"
echo "Running ${max} replicates at a time"
echo "Host: $(hostname)"
echo "Started: $(date)"

for REP in $(seq 1 "$total")
do
    echo "Starting replicate ${REP}"

    ./slim_runner_reps.sh "$REP" "$SWEEP" \
        > "$HOME/slim_runs/logs/${SWEEP}_${SLURM_JOB_ID}_rep${REP}.out" \
        2> "$HOME/slim_runs/logs/${SWEEP}_${SLURM_JOB_ID}_rep${REP}.err" &

    count=$((count + 1))

    if [ "$count" -ge "$max" ]; then
        wait
        count=0
    fi
done

wait

echo "Finished: $(date)"
