#!/bin/bash

# This submits each SLiM chunk as a separate Slurm job through Snakemake.

set -euo pipefail

CONFIG="rough_checkpoint_config.yaml"
SNAKEFILE="rough_Snakefile_checkpoint"

# Activate your snakemake environment here if needed:
# conda activate snakemake

JOBS=$(python - <<'PY'
import yaml
with open("rough_checkpoint_config.yaml") as f:
    cfg = yaml.safe_load(f)
print(cfg.get("jobs", 20))
PY
)


snakemake \
  --snakefile "$SNAKEFILE" \
  --configfile "$CONFIG" \
  --executor slurm \
  --jobs "$JOBS" \
  --latency-wait 90 \
  --rerun-incomplete \
  --keep-going \
  --printshellcmds
