#!/bin/bash
#SBATCH --account=usuplants-np
#SBATCH --partition=usuplants-np
#SBATCH --job-name=slim_param_test
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu

set -euo pipefail

module load parallel
module load slim/4.3

cd "$HOME/slim_runs/scripts"
mkdir -p "$HOME/slim_runs/logs"

SWEEP=$1

parallel -j 2 ./slim_runner.sh ::: $(seq 1 100) ::: "$SWEEP"
