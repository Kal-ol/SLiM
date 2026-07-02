#!/bin/bash

set -euo pipefail

CONFIG="${1:-INPUT_1.yaml}"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG"
    exit 1
fi

CONFIG_ABS="$(readlink -f "$CONFIG")"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARRAY_SCRIPT="$THIS_DIR/run_section_control.sh"

if [[ ! -f "$ARRAY_SCRIPT" ]]; then
    echo "ERROR: cannot find array script: $ARRAY_SCRIPT"
    exit 1
fi

cfg() {
    local key="$1"
    local val
    val=$(grep -E "^${key}:" "$CONFIG_ABS" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//" | sed -E 's/[[:space:]]+#.*$//')
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
    eval echo "$val"
}

MU_VALUES_STR="$(cfg mu_bdmi_values)"
read -r -a MU_VALUES <<< "$MU_VALUES_STR"

TOTAL_REPS="$(cfg total_reps)"
ENDGEN="$(cfg end_gen)"
SECTION="$(cfg section_size)"
MAX_PARALLEL="$(cfg max_parallel)"

SLURM_ACCOUNT="$(cfg slurm_account)"
SLURM_PARTITION="$(cfg slurm_partition)"
SLURM_QOS="$(cfg slurm_qos)"
TIME="$(cfg time)"
MEM="$(cfg mem)"
CPUS="$(cfg cpus_per_task)"

N_MU_VALUES="${#MU_VALUES[@]}"
TOTAL_TASKS=$(( N_MU_VALUES * TOTAL_REPS ))

if (( TOTAL_TASKS < 1 )); then
    echo "ERROR: TOTAL_TASKS is < 1. Check mu_bdmi_values and total_reps."
    exit 1
fi

if (( ENDGEN % SECTION != 0 )); then
    echo "ERROR: end_gen ($ENDGEN) must be divisible by section_size ($SECTION)."
    exit 1
fi

echo "============================================================"
echo "Submitting sectioned SLiM simulation pipeline"
echo "Config:        $CONFIG_ABS"
echo "Array script:  $ARRAY_SCRIPT"
echo "muBDMI values: ${MU_VALUES[*]}"
echo "Reps/rate:     $TOTAL_REPS"
echo "Total tasks:   $TOTAL_TASKS"
echo "section size:    $SECTION generations"
echo "End gen:       $ENDGEN"
echo "Max parallel:  $MAX_PARALLEL"
echo "Slurm:         account=$SLURM_ACCOUNT partition=$SLURM_PARTITION qos=$SLURM_QOS time=$TIME mem=$MEM cpus=$CPUS"
echo "============================================================"

prev_jobid=""

for (( section_end=SECTION; section_end<=ENDGEN; section_end+=SECTION )); do
    dep_arg=()
    if [[ -n "$prev_jobid" ]]; then
        dep_arg=(--dependency=aftercorr:$prev_jobid)
    fi

    qos_arg=()
    if [[ "$SLURM_QOS" != "NONE" && -n "$SLURM_QOS" ]]; then
        qos_arg=(--qos="$SLURM_QOS")
    fi

    echo "Submitting section ending at generation $section_end..."

    submit_out=$(
        sbatch \
            "${dep_arg[@]}" \
            --account="$SLURM_ACCOUNT" \
            --partition="$SLURM_PARTITION" \
            "${qos_arg[@]}" \
            --time="$TIME" \
            --cpus-per-task="$CPUS" \
            --mem="$MEM" \
            --array="1-${TOTAL_TASKS}%${MAX_PARALLEL}" \
            --export=ALL,CONFIG="$CONFIG_ABS",SECTION_END="$section_end" \
            "$ARRAY_SCRIPT"
    )

    jobid=$(echo "$submit_out" | awk '{print $4}')
    echo "  $submit_out"
    echo "  section gen $section_end job ID: $jobid"

    prev_jobid="$jobid"
done

echo "============================================================"
echo "All section rounds submitted."
echo "Last dependency chain job ID: $prev_jobid"
echo
echo "Check status:"
echo "  squeue --me"
echo
echo "Find finished simulations:"
echo "  find \$(eval echo \"$(cfg base)\")/results/$(cfg result_name) -name finished.done | sort"
echo "============================================================"

