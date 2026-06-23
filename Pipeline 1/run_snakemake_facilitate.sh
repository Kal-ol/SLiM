#!/bin/bash
# runs the snakefile to facilitate the jobs

set -euo pipefail

module load snakemake/9.17.2

snakemake \
  --snakefile Snakefile_simple_facilitator \
  --configfile simple_facilitator_config.yaml \
  --cores 1 \
  --printshellcmds \
  --rerun-incomplete
