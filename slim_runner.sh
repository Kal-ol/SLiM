#!/bin/bash

set -euo pipefail

IDX=$1
SWEEP=$2

module load slim/4.3

# Baseline values
hybridizationRate=0.001
recombRate=1e-3
mu_m1=1e-6
mu_m2=1e-6
sb=0.30
sigma_m=0.15
sigma_HI=0.20
alpha=0.01

# Sweep one parameter at a time (100 values)

if [ "$SWEEP" = "sigma" ]; then
    sigma_HI=$(awk -v i=$IDX 'BEGIN { print 0.001 + (1.0 - 0.001)*(i-1)/99 }')
    SWEEPVAL=$sigma_HI
fi

if [ "$SWEEP" = "hyb" ]; then
    hybridizationRate=$(awk -v i=$IDX 'BEGIN { print (i-1)/99 }')
    SWEEPVAL=$hybridizationRate
fi

if [ "$SWEEP" = "sb" ]; then
    sb=$(awk -v i=$IDX 'BEGIN { print (i-1)/99 }')
    SWEEPVAL=$sb
fi

if [ -z "${SWEEPVAL:-}" ]; then
    echo "Unknown sweep type: $SWEEP"
    echo "Use one of: sigma, hyb, sb"
    exit 1
fi

RUN_ID="${SWEEP}_idx${IDX}_val${SWEEPVAL}"
OUTPUT_DIR="$HOME/slim_runs/results/${RUN_ID}"
mkdir -p "$OUTPUT_DIR"

SEED=$((100000 + IDX))

echo "Running $SWEEP idx=$IDX value=$SWEEPVAL"

slim \
  -s "${SEED}" \
  -d "hybridizationRate=${hybridizationRate}" \
  -d "recombRate=${recombRate}" \
  -d "mu_m1=${mu_m1}" \
  -d "mu_m2=${mu_m2}" \
  -d "sb=${sb}" \
  -d "sigma_m=${sigma_m}" \
  -d "sigma_HI=${sigma_HI}" \
  -d "alpha=${alpha}" \
  -d "OUTFILE='${OUTPUT_DIR}/output.txt'" \
  "$HOME/slim_runs/scripts/hybrid_model.slim"
