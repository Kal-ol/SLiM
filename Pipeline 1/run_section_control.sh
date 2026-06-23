#!/bin/bash
#SBATCH --job-name=slim_section
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.out
#SBATCH --error=/uufs/chpc.utah.edu/common/home/u6050972/slim_runs/logs/%x_%A_%a.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=kallol.mozumdar@usu.edu


set -euo pipefail

if [[ -z "${CONFIG:-}" ]]; then
    echo "ERROR: CONFIG environment variable not set."
    exit 1
fi

if [[ -z "${SECTION_END:-}" ]]; then
    echo "ERROR: SECTION_END environment variable not set."
    exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG"
    exit 1
fi

cfg() {
    local key="$1"
    local val
    val=$(grep -E "^${key}:" "$CONFIG" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//" | sed -E 's/[[:space:]]+#.*$//')
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
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
SECTION="$(cfg section_size)"
REMEMBER_EVERY="$(cfg remember_every)"

MU_pheno="$(cfg mu_pheno)"
MU_NEUTRAL="$(cfg mu_neutral)"
HYB_RATE="$(cfg hyb_rate)"
ALPHA="$(cfg alpha)"
MAX_OVULES="$(cfg max_ovules)"

SLIM_MODULE="$(cfg slim_module)"

TASK_ID="${SLURM_ARRAY_TASK_ID}"
N_MU_VALUES="${#MU_VALUES[@]}"
TOTAL_TASKS=$(( N_MU_VALUES * TOTAL_REPS ))

if (( TASK_ID < 1 || TASK_ID > TOTAL_TASKS )); then
    echo "ERROR: SLURM_ARRAY_TASK_ID=$TASK_ID outside expected 1-$TOTAL_TASKS"
    exit 1
fi

mu_index=$(( (TASK_ID - 1) / TOTAL_REPS ))
REP=$(( (TASK_ID - 1) % TOTAL_REPS + 1 ))

MU_BDMI="${MU_VALUES[$mu_index]}"
value_code=$(( mu_index + 1 ))
SEED=$(( SEED_BASE + value_code * 1000 + REP ))

SECTION_END_INT=$(( SECTION_END ))
SECTION_START=$(( SECTION_END_INT - SECTION ))

if (( SECTION_START < 0 )); then
    echo "ERROR: section start < 0. Check section_size and section_END."
    exit 1
fi

gen4() {
    printf "%04d" "$1"
}

CURR_LABEL="$(gen4 "$SECTION_END_INT")"
PREV_LABEL="$(gen4 "$SECTION_START")"

ROOT="$BASE/results/$RESULT_NAME/$MODEL_NAME/$BDMI_ACCUM/$SCENARIO"
OUTDIR="$ROOT/muBDMI_${MU_BDMI}/rep${REP}_seed${SEED}"

CHECKDIR="$OUTDIR/checkpoints"
SECTIONDIR="$OUTDIR/section_outputs"
STATUSDIR="$OUTDIR/status"

mkdir -p "$CHECKDIR" "$SECTIONDIR" "$STATUSDIR" "$BASE/logs"

CHECKPOINT_OUT="$CHECKDIR/checkpoint_gen${CURR_LABEL}.bin"
CHECKPOINT_SEED_OUT="$CHECKDIR/checkpoint_gen${CURR_LABEL}.seed"
DONE_OUT="$STATUSDIR/section_gen${CURR_LABEL}.done"

if [[ -s "$DONE_OUT" && -s "$CHECKPOINT_OUT" && -s "$CHECKPOINT_SEED_OUT" ]]; then
    echo "section already complete; skipping:"
    echo "  $DONE_OUT"
    exit 0
fi

if (( SECTION_START == 0 )); then
    CHECKPOINT_IN="NONE"
    CHECKPOINT_SEED_IN="NONE"
else
    CHECKPOINT_IN="$CHECKDIR/checkpoint_gen${PREV_LABEL}.bin"
    CHECKPOINT_SEED_IN="$CHECKDIR/checkpoint_gen${PREV_LABEL}.seed"

    if [[ ! -s "$CHECKPOINT_IN" || ! -s "$CHECKPOINT_SEED_IN" ]]; then
        echo "ERROR: previous checkpoint missing for section ${PREV_LABEL} -> ${CURR_LABEL}"
        echo "Expected:"
        echo "  $CHECKPOINT_IN"
        echo "  $CHECKPOINT_SEED_IN"
        exit 1
    fi
fi

CSV_OUT="$SECTIONDIR/per_generation_gen${PREV_LABEL}_to_${CURR_LABEL}.csv"
CONSOLE_OUT="$SECTIONDIR/slim_console_gen${PREV_LABEL}_to_${CURR_LABEL}.txt"

TREESEQ_FINAL="final_gen${ENDGEN}.trees"
TREESEQ_BURNIN="burnin_gen${BURNIN}.trees"

if [[ ! -f "$SCRIPT" ]]; then
    echo "ERROR: SLiM script not found: $SCRIPT"
    exit 1
fi

cat <<INFO
============================================================
SLiM checkpoint section
Config: $CONFIG
Host: $(hostname)
Job ID: ${SLURM_JOB_ID:-NA}
Array task: ${SLURM_ARRAY_TASK_ID:-NA}

Model: $MODEL_NAME
muBDMI: $MU_BDMI
Replicate: $REP
Seed: $SEED

section: $SECTION_START -> $SECTION_END_INT
Checkpoint in: $CHECKPOINT_IN
Seed in: $CHECKPOINT_SEED_IN
Checkpoint out: $CHECKPOINT_OUT
Seed out: $CHECKPOINT_SEED_OUT

Burnin: $BURNIN
EndGen: $ENDGEN
Output dir: $OUTDIR
Started: $(date)
============================================================
INFO

module load "$SLIM_MODULE"

rm -f "$CHECKPOINT_OUT" "$CHECKPOINT_SEED_OUT" "$DONE_OUT" "$CONSOLE_OUT"

cd "$OUTDIR"

slim \
  -s "$SEED" \
  -t \
  -d burnin="$BURNIN" \
  -d endGen="$ENDGEN" \
  -d sectionStart="$SECTION_START" \
  -d sectionEnd="$SECTION_END_INT" \
  -d envScenario="'${SCENARIO}'" \
  -d bdmiAccumulation="'${BDMI_ACCUM}'" \
  -d mupheno="$MU_pheno" \
  -d muBDMI="$MU_BDMI" \
  -d muNeutral="$MU_NEUTRAL" \
  -d hybRate="$HYB_RATE" \
  -d alpha="$ALPHA" \
  -d maxOvules="$MAX_OVULES" \
  -d rememberEvery="$REMEMBER_EVERY" \
  -d outputFile="'${CSV_OUT}'" \
  -d treeSeqFile="'${TREESEQ_FINAL}'" \
  -d burninTreeSeqFile="'${TREESEQ_BURNIN}'" \
  -d checkpointIn="'${CHECKPOINT_IN}'" \
  -d checkpointSeedIn="'${CHECKPOINT_SEED_IN}'" \
  -d checkpointOut="'${CHECKPOINT_OUT}'" \
  -d checkpointSeedOut="'${CHECKPOINT_SEED_OUT}'" \
  "$SCRIPT" \
  > "$CONSOLE_OUT"

test -s "$CHECKPOINT_OUT"
test -s "$CHECKPOINT_SEED_OUT"

if (( SECTION_END_INT == BURNIN )); then
    test -s "$TREESEQ_BURNIN"
fi

if (( SECTION_END_INT == ENDGEN )); then
    test -s "$TREESEQ_FINAL"
    echo "finished model=$MODEL_NAME muBDMI=$MU_BDMI rep=$REP seed=$SEED at $(date)" > "$STATUSDIR/finished.done"
fi

echo "done model=$MODEL_NAME muBDMI=$MU_BDMI rep=$REP seed=$SEED section=${PREV_LABEL}_to_${CURR_LABEL} at $(date)" > "$DONE_OUT"

cat <<INFO
============================================================
Finished section: $SECTION_START -> $SECTION_END_INT
Finished: $(date)
Checkpoint written:
  $CHECKPOINT_OUT
  $CHECKPOINT_SEED_OUT
============================================================
INFO
