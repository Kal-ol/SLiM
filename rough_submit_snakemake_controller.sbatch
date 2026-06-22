#!/bin/bash
#SBATCH --account=rushworth
#SBATCH --partition=kingspeak
#SBATCH --qos=kingspeak
#SBATCH --job-name=snake_muBDMI_ctrl
#SBATCH --time=72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.err

set -euo pipefail

# This runs snakemake, which in turn submits slurm jobs 

cd /uufs/chpc.utah.edu/common/home/u6050972/slim_runs/workflows/muBDMI_checkpoint
./rough_run_snakemake_slurm.sh
