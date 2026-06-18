#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: ./slim_runner_reps.sh <array_index> <hyb|sb|alpha|sigma|recomb|mut>"
    exit 1
fi

IDX="$1"
SWEEP="$2"

# -----------------------------
# Baseline values (held constant unless swept)
# -----------------------------
hybridizationRate=0.001
recombRate=1e-3
mu_m1=1e-6
mu_m2=1e-6
sb=0.30
sigma_m=0.15
sigma_HI=0.20
alpha=0.01

# -----------------------------
# Map 300 array tasks -> 3 values x 100 replicates
# tasks   1-100   = value 1, reps 1-100
# tasks 101-200   = value 2, reps 1-100
# tasks 201-300   = value 3, reps 1-100
# -----------------------------
if [ "$IDX" -lt 1 ] || [ "$IDX" -gt 300 ]; then
    echo "Array index must be between 1 and 300; got: $IDX"
    exit 1
fi

value_index=$(( (IDX - 1) / 100 + 1 ))
rep=$(( (IDX - 1) % 100 + 1 ))

case "$SWEEP" in
    hyb)
        case "$value_index" in
            1) hybridizationRate=0.25 ;;
            2) hybridizationRate=0.50 ;;
            3) hybridizationRate=0.75 ;;
        esac
        SWEEPVAL="$hybridizationRate"
        ;;

    sb)
        case "$value_index" in
            1) sb=0.25 ;;
            2) sb=0.50 ;;
            3) sb=0.75 ;;
        esac
        SWEEPVAL="$sb"
        ;;

    alpha)
        case "$value_index" in
            1) alpha=0.005 ;;
            2) alpha=0.02 ;;
            3) alpha=0.05 ;;
        esac
        SWEEPVAL="$alpha"
        ;;

    sigma)
        case "$value_index" in
            1) sigma_HI=0.02 ;;
            2) sigma_HI=0.4 ;;
            3) sigma_HI=0.8 ;;
        esac
        SWEEPVAL="$sigma_HI"
        ;;

    recomb)
        case "$value_index" in
            1) recombRate=1e-8 ;;
            2) recombRate=1e-5 ;;
            3) recombRate=1e-2 ;;
        esac
        SWEEPVAL="$recombRate"
        ;;

    mut)
        case "$value_index" in
            1) mu_m1=1e-10; mu_m2=1e-10 ;;
            2) mu_m1=1e-8 ; mu_m2=1e-8  ;;
            3) mu_m1=1e-6 ; mu_m2=1e-6  ;;
        esac
        SWEEPVAL="$mu_m1"
        ;;

    *)
        echo "Unknown sweep type: $SWEEP"
        echo "Allowed values: hyb | sb | alpha | sigma | recomb | mut"
        exit 1
        ;;
esac

RUN_ID="${SWEEP}_val${SWEEPVAL}_rep${rep}"
OUTPUT_DIR="$HOME/slim_runs/results/${SWEEP}/${RUN_ID}"
mkdir -p "$OUTPUT_DIR"

# Keep seeds unique across sweep/value/rep combinations
# value_index in {1,2,3}, rep in {1..100}
case "$SWEEP" in
    hyb)    sweep_code=1 ;;
    sb)     sweep_code=2 ;;
    alpha)  sweep_code=3 ;;
    sigma)  sweep_code=4 ;;
    recomb) sweep_code=5 ;;
    mut)    sweep_code=6 ;;
    *)      sweep_code=0 ;;
esac
SEED=$(( 100000 + sweep_code * 1000 + value_index * 100 + rep ))

echo "----------------------------------------"
echo "Sweep      : $SWEEP"
echo "Value idx  : $value_index"
echo "Replicate  : $rep"
echo "Value      : $SWEEPVAL"
echo "Seed       : $SEED"
echo "Output dir : $OUTPUT_DIR"
echo "----------------------------------------"

slim \
  -s "$SEED" \
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
