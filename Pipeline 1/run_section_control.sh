#!/bin/bash
#SBATCH --account=rushworth
#SBATCH --partition=kingspeak
#SBATCH --qos=kingspeak
#SBATCH --job-name=slim_section
#SBATCH --time=72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu

# One Slurm job = one SLiM section for one model/rate/replicate.
# This script finds the latest checkpoint, runs the next section, saves a new checkpoint, and resubmits itself until ENDGEN is reached.

set -euo pipefail

if [[ $# -ne 17 ]]; then
    echo "ERROR: Expected 17 arguments, got $#"
    echo "Usage: sbatch run_section_controller.sh MODEL SCRIPT MU_BDMI REP SEED REPDIR BDMI_ACCUM SCENARIO BURNIN ENDGEN section REMEMBER_EVERY MU_PHENO MU_NEUTRAL HYB_RATE ALPHA MAX_OVULES"
    exit 1
fi

MODEL="$1"
SCRIPT="$2"
MU_Pheno="$3"
REP="$4"
SEED="$5"
REPDIR="$6"
BDMI_ACCUM="$7"
SCENARIO="$8"
BURNIN="$9"
ENDGEN="${10}"
section="${11}"
REMEMBER_EVERY="${12}"
MU_PHENO="${13}"
MU_NEUTRAL="${14}"
HYB_RATE="${15}"
ALPHA="${16}"
MAX_OVULES="${17}"

module load slim/4.3

CONTROLLER=$(readlink -f "$0")
mkdir -p "$REPDIR/checkpoints" "$REPDIR/section_outputs" "$REPDIR/status" "$REPDIR/logs"

if [[ -f "$REPDIR/status/finished.done" ]]; then
    echo "Already finished: $REPDIR"
    exit 0
fi

# Find latest completed checkpoint by requiring all three files:
# checkpoint_genXXXX.bin + checkpoint_genXXXX.seed + section_genXXXX.done
latest_gen=0
for state in "$REPDIR"/checkpoints/checkpoint_gen*.bin; do
    [[ -e "$state" ]] || continue
    base=$(basename "$state")
    gen_str=${base#checkpoint_gen}
    gen_str=${gen_str%.bin}
    gen_num=$((10#$gen_str))
    seed_file="$REPDIR/checkpoints/checkpoint_gen${gen_str}.seed"
    done_file="$REPDIR/status/section_gen${gen_str}.done"
    if [[ -s "$state" && -s "$seed_file" && -s "$done_file" ]]; then
        if (( gen_num > latest_gen )); then
            latest_gen=$gen_num
        fi
    fi
done

if (( latest_gen >= ENDGEN )); then
    if [[ -s "$REPDIR/final_gen${ENDGEN}.trees" ]]; then
        echo "finished at $(date)" > "$REPDIR/status/finished.done"
        echo "Replicate already reached ENDGEN=$ENDGEN"
        exit 0
    else
        echo "ERROR: latest checkpoint is ENDGEN=$ENDGEN, but final tree is missing: $REPDIR/final_gen${ENDGEN}.trees"
        exit 1
    fi
fi

section_start=$latest_gen
section_end=$(( latest_gen + section ))
if (( section_end > ENDGEN )); then
    section_end=$ENDGEN
fi

gen_start4=$(printf "%04d" "$section_start")
gen_end4=$(printf "%04d" "$section_end")

if (( section_start == 0 )); then
    checkpoint_in="NONE"
    checkpoint_seed_in="NONE"
else
    checkpoint_in="$REPDIR/checkpoints/checkpoint_gen${gen_start4}.bin"
    checkpoint_seed_in="$REPDIR/checkpoints/checkpoint_gen${gen_start4}.seed"
fi

checkpoint_out="$REPDIR/checkpoints/checkpoint_gen${gen_end4}.bin"
checkpoint_seed_out="$REPDIR/checkpoints/checkpoint_gen${gen_end4}.seed"
done_out="$REPDIR/status/section_gen${gen_end4}.done"
output_csv="$REPDIR/section_outputs/per_generation_gen${gen_start4}_to_${gen_end4}.csv"
console="$REPDIR/section_outputs/slim_console_gen${gen_start4}_to_${gen_end4}.txt"

cat <<INFO
============================================================
SLiM section controller
Model: $MODEL
Script: $SCRIPT
muBDMI: $MU_BDMI
Replicate: $REP
Seed: $SEED
Repdir: $REPDIR
section: $section_start -> $section_end
Checkpoint in: $checkpoint_in
Checkpoint seed in: $checkpoint_seed_in
Checkpoint out: $checkpoint_out
Checkpoint seed out: $checkpoint_seed_out
Started: $(date)
Host: $(hostname)
============================================================
INFO

rm -f "$checkpoint_out" "$checkpoint_seed_out" "$done_out" "$console"

cd "$REPDIR"

slim \
  -s "$SEED" \
  -t \
  -d burnin="$BURNIN" \
  -d endGen="$ENDGEN" \
  -d sectionStart="$section_start" \
  -d sectionEnd="$section_end" \
  -d envScenario="'$SCENARIO'" \
  -d bdmiAccumulation="'$BDMI_ACCUM'" \
  -d mupheno="$MU_PHENO" \
  -d muBDMI="$MU_BDMI" \
  -d muNeutral="$MU_NEUTRAL" \
  -d hybRate="$HYB_RATE" \
  -d alpha="$ALPHA" \
  -d maxOvules="$MAX_OVULES" \
  -d rememberEvery="$REMEMBER_EVERY" \
  -d outputFile="'$output_csv'" \
  -d treeSeqFile="'final_gen${ENDGEN}.trees'" \
  -d burninTreeSeqFile="'burnin_gen${BURNIN}.trees'" \
  -d checkpointIn="'$checkpoint_in'" \
  -d checkpointSeedIn="'$checkpoint_seed_in'" \
  -d checkpointOut="'$checkpoint_out'" \
  -d checkpointSeedOut="'$checkpoint_seed_out'" \
  "$SCRIPT" > "$console"

test -s "$checkpoint_out"
test -s "$checkpoint_seed_out"
echo "done section ${section_start}->${section_end} at $(date)" > "$done_out"

if (( section_end == BURNIN )); then
    if [[ -s "$REPDIR/burnin_gen${BURNIN}.trees" ]]; then
        echo "Burn-in tree exists: $REPDIR/burnin_gen${BURNIN}.trees"
    else
        echo "WARNING: reached BURNIN=$BURNIN but burnin tree not found. Check SLiM checkpoint code."
    fi
fi

if (( section_end >= ENDGEN )); then
    test -s "$REPDIR/final_gen${ENDGEN}.trees"
    echo "finished at $(date)" > "$REPDIR/status/finished.done"
    echo "Finished full replicate: $REPDIR"
else
    jid=$(sbatch --parsable "$CONTROLLER" \
        "$MODEL" "$SCRIPT" "$MU_BDMI" "$REP" "$SEED" "$REPDIR" \
        "$BDMI_ACCUM" "$SCENARIO" "$BURNIN" "$ENDGEN" "$section" "$REMEMBER_EVERY" \
        "$MU_PHENO" "$MU_NEUTRAL" "$HYB_RATE" "$ALPHA" "$MAX_OVULES")
    echo "$jid" > "$REPDIR/status/next_section_after_gen${gen_end4}_jobid.txt"
    echo "Submitted next section job: $jid"
fi

cat <<INFO
============================================================
section finished: $(date)
Output directory: $REPDIR
============================================================
INFO
