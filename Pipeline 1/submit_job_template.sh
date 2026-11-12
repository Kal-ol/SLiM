#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 ACCOUNT PARTITION" >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
control="$script_dir/run_full_example_task.sh"
model="$script_dir/06_22_2026_model_v4_6.slim"
output_root="$script_dir/../results/full_example"

[[ -r "$control" && -r "$model" ]] || {
    echo "Expected the control script and SLiM model beside the launcher." >&2
    exit 1
}
mkdir -p "$output_root/logs"


sbatch \
    --job-name=slim_full_example \
    --account="$1" \
    --partition="$2" \
    --array=1-3 \
    --cpus-per-task=1 \
    --mem=8G \
    --time=24:00:00 \
    --output="$output_root/logs/%x_%A_%a.out" \
    "$control" "$model" "$output_root"

# Pass a QoS only if the configuration specifies
QOS=$(cfg slurm_qos "")
[[ -z $QOS ]] || ARGS+=(--qos="$QOS")
sbatch "${ARGS[@]}" "$CONTROL" "$CONFIG"
