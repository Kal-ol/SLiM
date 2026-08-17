#!/bin/bash

set -euo pipefail

CONFIG="${1:-INPUT_1_full.yaml}"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG" >&2
    exit 1
fi

CONFIG_ABS="$(readlink -f "$CONFIG")"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARRAY_SCRIPT="$THIS_DIR/run_full_control.sh"

if [[ ! -f "$ARRAY_SCRIPT" ]]; then
    echo "ERROR: array script not found: $ARRAY_SCRIPT" >&2
    exit 1
fi

cfg() {
    local key="$1"
    local val

    val=$(grep -E "^${key}:" "$CONFIG_ABS" | head -n 1 | \
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

MU_VALUES_STR="$(cfg mu_bdmi_values)"
read -r -a MU_VALUES <<< "$MU_VALUES_STR"

TOTAL_REPS="$(cfg total_reps)"
MAX_PARALLEL="$(cfg max_parallel)"
SLURM_ACCOUNT="$(cfg slurm_account)"
SLURM_PARTITION="$(cfg slurm_partition)"
SLURM_QOS="$(cfg slurm_qos)"
TIME_LIMIT="$(cfg time)"
MEMORY="$(cfg mem)"
CPUS="$(cfg cpus_per_task)"

for value_name in TOTAL_REPS MAX_PARALLEL CPUS; do
    if ! [[ "${!value_name}" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: $value_name must be a positive integer; got ${!value_name}" >&2
        exit 1
    fi
done

TOTAL_TASKS=$(( ${#MU_VALUES[@]} * TOTAL_REPS ))
if (( TOTAL_TASKS < 1 )); then
    echo "ERROR: no array tasks were generated" >&2
    exit 1
fi

qos_arg=()
if [[ -n "$SLURM_QOS" && "$SLURM_QOS" != "NONE" ]]; then
    qos_arg=(--qos="$SLURM_QOS")
fi

echo "Submitting uninterrupted SLiM array"
echo "Config:        $CONFIG_ABS"
echo "muBDMI values: ${MU_VALUES[*]}"
echo "Reps/value:    $TOTAL_REPS"
echo "Total tasks:   $TOTAL_TASKS"
echo "Max parallel:  $MAX_PARALLEL"

submit_out=$(
    sbatch \
        --account="$SLURM_ACCOUNT" \
        --partition="$SLURM_PARTITION" \
        "${qos_arg[@]}" \
        --time="$TIME_LIMIT" \
        --cpus-per-task="$CPUS" \
        --mem="$MEMORY" \
        --mail-type=END,FAIL \
        --mail-user=kallol.mozumdar@usu.edu \
        --array="1-${TOTAL_TASKS}%${MAX_PARALLEL}" \
        --export=ALL,CONFIG="$CONFIG_ABS" \
        "$ARRAY_SCRIPT"
)

job_id="$(awk '{print $4}' <<< "$submit_out")"
if [[ ! "$job_id" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not parse job ID from sbatch output:" >&2
    echo "$submit_out" >&2
    exit 1
fi

echo "$submit_out"
echo "Check status: squeue -j $job_id"

