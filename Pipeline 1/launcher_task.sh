#!/usr/bin/env bash
set -euo pipefail

check=0
if [[ ${1:-} == --check ]]; then
    check=1
    shift
fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check] CONFIG.yaml" >&2; exit 1; }

here=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
config=$(realpath -e "$1")
settings=$(python3 "$here/full_run_config.py" submit "$config")
mapfile -t args <<< "$settings"
out=${args[0]}

if (( check )); then
    printf 'Output root: %s\n' "$out"
    printf '%s\n' "${args[@]:1}"
    exit 0
fi

mkdir -p "$out/logs"
sbatch --job-name=slim_full \
    --output="$out/logs/%x_%A_%a.out" \
    "${args[@]:1}" "$here/run_full_run_task.sh" "$config" "$here"
