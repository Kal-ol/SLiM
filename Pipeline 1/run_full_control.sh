#!/bin/bash
#SBATCH --job-name=slim_full
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu

set -euo pipefail

CONFIG="${CONFIG:-${1:-INPUT_1_full.yaml}}"
if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG" >&2
    exit 1
fi

cfg() {
    local key="$1"
    local val

    val=$(grep -E "^${key}:" "$CONFIG" | head -n 1 | \
          sed -E "s/^${key}:[[:space:]]*//" | \
          sed -E 's/[[:space:]]+#.*$//' || true)
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"

    if [[ -z "$val" ]]; then
        echo "ERROR: missing or blank config key: $key" >&2
        exit 1
    fi

    eval echo "$val"
}

BASE="$(cfg base)"
RESULT_NAME="$(cfg result_name)"
MODEL_NAME="$(cfg model_name)"
SCRIPT="$(cfg slim_script)"
BDMI_ACCUM="$(cfg bdmi_accumulation)"
SCENARIO="$(cfg scenario)"

MU_VALUES_STR="$(cfg mu_bdmi_values)"
read -r -a MU_VALUES <<< "$MU_VALUES_STR"
TOTAL_REPS="$(cfg total_reps)"

BURNIN="$(cfg burnin)"
ENDGEN="$(cfg end_gen)"
REMEMBER_EVERY="$(cfg remember_every)"
MU_PHENO="$(cfg mu_pheno)"
MU_NEUTRAL="$(cfg mu_neutral)"
HYB_RATE="$(cfg hyb_rate)"
ALPHA="$(cfg alpha)"
MAX_OVULES="$(cfg max_ovules)"
SLIM_MODULE="$(cfg slim_module)"

for value_name in TOTAL_REPS BURNIN ENDGEN REMEMBER_EVERY MAX_OVULES; do
    if ! [[ "${!value_name}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: $value_name must be a positive integer; got ${!value_name}" >&2
        exit 1
    fi
done

if (( BURNIN >= ENDGEN )); then
    echo "ERROR: burnin ($BURNIN) must be smaller than end_gen ($ENDGEN)" >&2
    exit 1
fi

# The supplied v4.1 model schedules its recurring callbacks through tick 5000.
if (( ENDGEN > 5000 )); then
    echo "ERROR: end_gen=$ENDGEN exceeds the model's callback limit of 5000" >&2
    exit 1
fi

TASK_ID="${SLURM_ARRAY_TASK_ID:-${TASK_ID:-1}}"
TOTAL_TASKS=$(( ${#MU_VALUES[@]} * TOTAL_REPS ))
if ! [[ "$TASK_ID" =~ ^[1-9][0-9]*$ ]] || (( TASK_ID > TOTAL_TASKS )); then
    echo "ERROR: task ID $TASK_ID is outside 1-$TOTAL_TASKS" >&2
    exit 1
fi

mu_index=$(( (TASK_ID - 1) / TOTAL_REPS ))
REP=$(( (TASK_ID - 1) % TOTAL_REPS + 1 ))
MU_BDMI="${MU_VALUES[$mu_index]}"

if [[ ! -f "$SCRIPT" ]]; then
    echo "ERROR: SLiM script not found: $SCRIPT" >&2
    exit 1
fi

OUTDIR="$BASE/results/$RESULT_NAME/$MODEL_NAME/$BDMI_ACCUM/$SCENARIO/muBDMI_${MU_BDMI}/rep${REP}"
STATUSDIR="$OUTDIR/status"
mkdir -p "$OUTDIR" "$STATUSDIR" "$BASE/logs"

CSV_OUT="$OUTDIR/per_generation.csv"
CONSOLE_OUT="$OUTDIR/slim_console.txt"
BURNIN_TREE="$OUTDIR/burnin_gen${BURNIN}.trees"
FINAL_TREE="$OUTDIR/final_gen${ENDGEN}.trees"
CHECKPOINT_OUT="$OUTDIR/checkpoint_final.bin"
CHECKPOINT_SEED_OUT="$OUTDIR/checkpoint_final.seed"
PHENO_EFFECTS_OUT="$OUTDIR/phenotype_effects.csv"
DONE_OUT="$STATUSDIR/finished.done"

required_outputs=(
    "$CSV_OUT" "$BURNIN_TREE" "$FINAL_TREE" "$CHECKPOINT_OUT"
    "$CHECKPOINT_SEED_OUT" "$PHENO_EFFECTS_OUT"
)

if [[ -s "$DONE_OUT" ]]; then
    all_present=true
    for output in "${required_outputs[@]}"; do
        [[ -s "$output" ]] || all_present=false
    done
    if [[ "$all_present" == true ]]; then
        echo "Run already complete; skipping $OUTDIR"
        exit 0
    fi
fi

echo "Model:       $MODEL_NAME"
echo "muBDMI:      $MU_BDMI"
echo "Replicate:   $REP"
echo "Generations: 1-$ENDGEN"
echo "Output:      $OUTDIR"
echo "Started:     $(date)"

module load "$SLIM_MODULE"

# Remove only outputs belonging to this exact parameter/replicate directory.
rm -f "${required_outputs[@]}" "$DONE_OUT" "$CONSOLE_OUT"

cd "$OUTDIR"

slim \
    -t \
    -d burnin="$BURNIN" \
    -d endGen="$ENDGEN" \
    -d envScenario="'${SCENARIO}'" \
    -d bdmiAccumulation="'${BDMI_ACCUM}'" \
    -d mupheno="$MU_PHENO" \
    -d muBDMI="$MU_BDMI" \
    -d muNeutral="$MU_NEUTRAL" \
    -d hybRate="$HYB_RATE" \
    -d alpha="$ALPHA" \
    -d maxOvules="$MAX_OVULES" \
    -d rememberEvery="$REMEMBER_EVERY" \
    -d outputFile="'${CSV_OUT}'" \
    -d treeSeqFile="'${FINAL_TREE}'" \
    -d burninTreeSeqFile="'${BURNIN_TREE}'" \
    -d checkpointOut="'${CHECKPOINT_OUT}'" \
    -d checkpointSeedOut="'${CHECKPOINT_SEED_OUT}'" \
    -d phenoEffectsOut="'${PHENO_EFFECTS_OUT}'" \
    "$SCRIPT" > "$CONSOLE_OUT"

for output in "${required_outputs[@]}"; do
    if [[ ! -s "$output" ]]; then
        echo "ERROR: expected output is missing or empty: $output" >&2
        tail -n 50 "$CONSOLE_OUT" || true
        exit 1
    fi
done

csv_last_generation="$(tail -n 1 "$CSV_OUT" | cut -d, -f1)"
if [[ "$csv_last_generation" != "$ENDGEN" ]]; then
    echo "ERROR: CSV ended at generation $csv_last_generation, expected $ENDGEN" >&2
    exit 1
fi

echo "finished model=$MODEL_NAME muBDMI=$MU_BDMI rep=$REP generation=$ENDGEN at $(date)" > "$DONE_OUT"
echo "Completed: $(date)"
