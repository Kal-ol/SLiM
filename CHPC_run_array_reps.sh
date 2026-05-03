#!/bin/bash
#SBATCH --account=usuplants-np
#SBATCH --partition=usuplants-np
#SBATCH --job-name=slim_reps
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --array=1-300%6
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: sbatch run_array_reps.sh <hyb|sb|alpha|sigma|recomb|mut>"
    exit 1
fi

module load slim/4.3

cd "$HOME/slim_runs/scripts"
mkdir -p "$HOME/slim_runs/logs"

SWEEP="$1"
IDX="$SLURM_ARRAY_TASK_ID"

echo "Running sweep=${SWEEP} array_task=${IDX} on $(hostname)"
./slim_runner_reps.sh "$IDX" "$SWEEP"
