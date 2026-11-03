#!/bin/bash
#SBATCH --job-name=slim_env_hyb_corrected
#SBATCH --nodes=1
#SBATCH --ntasks=1
set -euo pipefail

# CONFIG can be exported by sbatch or supplied for a local check.
CHECK_ONLY=0
if [[ ${1:-} == --check ]]; then CHECK_ONLY=1; shift; fi
CONFIG=$(realpath -e "${1:-${CONFIG:?Supply CONFIG.yaml or export CONFIG}}")
# This configuration uses flat YAML scalars. Parse them without requiring PyYAML.
cfg() {
    python3 - "$CONFIG" "$1" "${2-}" "${2+x}" <<'PY'
import ast, re, sys
path, key, default, has_default = sys.argv[1:]
for line in open(path):
    m = re.match(r'^([A-Za-z_][A-Za-z_0-9]*):\s*(.*?)\s*$', line)
    if not m or m[1] != key:
        continue
    value = m[2]
    if value.startswith(('"', "'")):
        value = ast.literal_eval(value)
    else:
        value = value.split(' #', 1)[0].strip()
    if not isinstance(value, str) or any(c in value for c in '\n\r\t'):
        sys.exit('Invalid scalar for ' + key)
    print(value)
    break
else:
    if has_default:
        print(default)
    else:
        sys.exit('Missing required configuration key: ' + key)
PY
}
fail() { echo "ERROR: $*" >&2; exit 1; }
eidos_string() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }
BASE=$(realpath -e "$(cfg base)")
RESULT=$(cfg result_name); BURNRES=$(cfg burnin_result_name)
SCRIPT=$(realpath -e "$(cfg slim_script)")
# Do not accidentally run the old cluster copy under a familiar filename.
for marker in 'Strict outcrossing:' 'N_viable_p1' 'protectRunInputs' 'writeEligibility'; do
    grep -Fq "$marker" "$SCRIPT" || fail "SLiM script lacks correction: $marker"
done
read -ra SCEN <<< "$(cfg scenarios)"
read -ra HYB <<< "$(cfg hyb_rates)"
read -ra Z1 <<< "$(cfg theta1_z1_values)"
read -ra Z2 <<< "$(cfg theta1_z2_values)"
REPS=$(cfg total_reps); ID=${SLURM_ARRAY_TASK_ID:?Set SLURM_ARRAY_TASK_ID for a local check}
[[ $REPS =~ ^[1-9][0-9]*$ && $ID =~ ^[1-9][0-9]*$ ]] || fail 'Invalid replicate/task number'
NH=${#HYB[@]}; NS=${#SCEN[@]}
(( NH > 0 && NS > 0 && ${#Z1[@]} > 0 && ${#Z1[@]} == ${#Z2[@]} )) || fail 'Empty or mismatched treatment lists'
PERTHETA=$((NS*NH)); C=$(((ID-1)/REPS)); REP=$(((ID-1)%REPS+1))
TI=$((C/PERTHETA)); R=$((C%PERTHETA)); SI=$((R/NH)); HI=$((R%NH))
(( TI < ${#Z1[@]} )) || fail 'Task ID exceeds treatment grid'
LABEL="z1_${Z1[$TI]}_z2_${Z2[$TI]}"; SC=${SCEN[$SI]}; HR=${HYB[$HI]}
case "$SC" in same_env|neutral|theta1|theta2|twohab|novel) ;; *) fail "Unknown scenario: $SC";; esac
BURNIN=$(cfg burnin 2000); END=$(cfg end_gen 4000)
[[ $BURNIN =~ ^[0-9]+$ && $END =~ ^[0-9]+$ ]] || fail 'Invalid cycle limits'
(( BURNIN < END && END <= 5000 )) || fail 'Require burnin < end_gen <= 5000'
[[ $(cfg record_tree_seq false) == false && $(cfg write_final_tree false) == false ]] || fail 'This demographic sweep requires tree recording/output disabled'

T1Z1=${Z1[$TI]}; T1Z2=${Z2[$TI]}; GROUP_INDEX=$TI
if [[ $SC == same_env ]]; then
    T1Z1=$(cfg same_env_theta1_z1); T1Z2=$(cfg same_env_theta1_z2)
    GROUP_INDEX=$(( ${#Z1[@]} + TI ))
    SUBDIR=$(cfg same_env_burnin_subdir)
else
    SUBDIR=$(cfg divergent_burnin_subdir)
fi
LABEL="z1_${T1Z1}_z2_${T1Z2}"
if [[ $SUBDIR == AUTO ]]; then
    SUBDIR=$(python3 - "$BASE/results/$BURNRES" "$T1Z1" "$T1Z2" <<'PYGROUP'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]); parent=root/'annual_base'/'burnin'
found=[]
if parent.is_dir():
    for p in parent.iterdir():
        m=re.fullmatch(r'theta1_z1_([^_]+)_z2_([^_]+)',p.name)
        if m and p.is_dir() and tuple(map(float,m.groups()))==tuple(map(float,sys.argv[2:])):
            found.append(p.relative_to(root))
if len(found)!=1:
    sys.exit('Set same_env_burnin_subdir to the actual existing group directory; coordinate lookup was missing or ambiguous.')
print(found[0])
PYGROUP
)
fi
BURN=$(realpath -e "$BASE/results/$BURNRES/$SUBDIR/rep$REP")
CHECKPOINT=$(realpath -e "$BURN/burnin_gen${BURNIN}.bin")
EFFECTS=$(realpath -e "$BURN/phenotype_effects.csv")
[[ -s $CHECKPOINT && -s $EFFECTS && -s $BURN/status/finished.done ]] || fail "Missing/incomplete burn-in: $BURN"
ELIGIBILITY=NONE
if [[ -f "$CHECKPOINT.eligibility.csv" ]]; then ELIGIBILITY=$(realpath -e "$CHECKPOINT.eligibility.csv"); fi
# Use a common eligibility seed for each source burn-in, not one per treatment.
SOURCESEED=NONE
for candidate in "$(cfg burnin_seed_file "burnin_gen${BURNIN}.seed")" "burnin_gen${BURNIN}.seed" checkpoint.seed; do
    if [[ -s "$BURN/$candidate" ]]; then SOURCESEED=$(realpath -e "$BURN/$candidate"); break; fi
done
if [[ $SOURCESEED != NONE ]]; then
    SEED=$(head -n1 "$SOURCESEED")
    SEED_ORIGIN="$SOURCESEED"
else
    SEED=$(( $(cfg seed_base) + GROUP_INDEX*REPS + REP ))
    SEED_ORIGIN='deterministic legacy reconstruction (no original seed file found)'
fi
[[ $SEED =~ ^[1-9][0-9]*$ ]] || fail 'Restart seed must be a positive integer'

RESULTROOT=$(realpath -m "$BASE/results/$RESULT")
BURNROOT=$(realpath -e "$BASE/results/$BURNRES")
[[ $RESULTROOT != "$BURNROOT" && $RESULTROOT != "$BURNROOT/"* ]] || fail 'Results must be outside the burn-in tree'
OUT=$(realpath -m "$RESULTROOT/annual_base/$SC/theta1_$LABEL/hybRate_$HR/rep$REP")
[[ $OUT != "$BURNROOT" && $OUT != "$BURNROOT/"* ]] || fail 'Output resolves inside the burn-in tree'
CSV="$OUT/per_generation_gen$((BURNIN+1))_to_${END}.csv"
CONSOLE="$OUT/slim_console.txt"; DONE="$OUT/status/finished.done"
BRANCHSEED="$OUT/restart.seed"
PARAMS=("burnin=$BURNIN" "endGen=$END" "sectionStart=$BURNIN" "sectionEnd=$END"
    "envScenario=$(eidos_string "$SC")" "hybRate=$HR"
    "theta1_z1=$T1Z1" "theta1_z2=$T1Z2"
    'recordTreeSeq=F' 'writeFinalTree=F')
for pair in K_p1:K_p1 K_p2:K_p2 K_p3:K_p3 theta2_z1:theta2_z1 theta2_z2:theta2_z2 \
    ancestral_z1:ancestral_z1 ancestral_z2:ancestral_z2 mupheno:mu_pheno muBDMI:mu_bdmi \
    muNeutral:mu_neutral recomb:recombination_rate sb:sb h_bdmi:h_bdmi traitSigma:trait_sigma \
    compSigma:competition_sigma mateSigma:mate_sigma epsilonMate:epsilon_mate \
    phenoLambda:pheno_lambda alpha:alpha dd_rate0:dd_rate0 maxOvules:max_ovules; do
    key=${pair#*:}
    if [[ $SC == same_env && ( $key == ancestral_z1 || $key == ancestral_z2 ) ]]; then
        key="same_env_$key"
    fi
    value=$(cfg "$key")
    [[ $value =~ ^[-+]?[0-9]+([.][0-9]*)?([eE][-+]?[0-9]+)?$ ]] || fail "Invalid numeric setting: $pair=$value"
    PARAMS+=("${pair%%:*}=$value")
done
PARAMS+=("bdmiAccumulation=$(eidos_string "$(cfg bdmi_accumulation)")")
if [[ $SC == novel ]]; then
    PARAMS+=("thetaN_z1=$(cfg novel_z1)" "thetaN_z2=$(cfg novel_z2)")
fi
case $(cfg write_final_checkpoint true) in
    true) PARAMS+=('writeFinalCheckpoint=T');;
    false) PARAMS+=('writeFinalCheckpoint=F');;
    *) fail 'write_final_checkpoint must be true or false';;
esac
SOURCESEED_ARG=$SOURCESEED
if [[ $SOURCESEED_ARG == NONE ]]; then SOURCESEED_ARG=$BRANCHSEED; fi
for pair in "checkpointIn:$CHECKPOINT" "checkpointSeedIn:$SOURCESEED_ARG" "phenoEffectsIn:$EFFECTS" \
    "eligibilityIn:$ELIGIBILITY" "outputFile:$CSV" "sampledPhenotypeFile:$OUT/sampled_individual_phenotypes.csv" \
    "checkpointOut:$OUT/postburn_gen${END}.bin" "checkpointSeedOut:$OUT/postburn_gen${END}.seed" \
    "phenoEffectsOut:$OUT/phenotype_effects.csv" "eligibilityOut:$OUT/postburn_gen${END}.bin.eligibility.csv"; do
    PARAMS+=("${pair%%:*}=$(eidos_string "${pair#*:}")")
done
# Resolve existing symlinks as well as ./ and ../ before comparing every output
# against every input. Include logs/status files written by the launcher itself.
INPUTS=("$CONFIG" "$SCRIPT" "$CHECKPOINT" "$EFFECTS")
[[ $SOURCESEED == NONE ]] || INPUTS+=("$SOURCESEED")
[[ $ELIGIBILITY == NONE ]] || INPUTS+=("$ELIGIBILITY")
OUTPUTS=("$OUT/config_used.yaml" "$OUT/command_used.txt" "$CSV" "$CONSOLE" "$DONE" "$BRANCHSEED" "$OUT/sampled_individual_phenotypes.csv"
    "$OUT/postburn_gen${END}.bin" "$OUT/postburn_gen${END}.seed"
    "$OUT/phenotype_effects.csv" "$OUT/postburn_gen${END}.bin.eligibility.csv")
for output in "${OUTPUTS[@]}"; do
    resolved=$(realpath -m "$output")
    for input in "${INPUTS[@]}"; do
        [[ $resolved != "$input" ]] || fail "Output overlaps burn-in input: $output"
        if [[ -e $output && $output -ef $input ]]; then fail "Output aliases burn-in input: $output"; fi
    done
done
printf 'task=%s scenario=%s theta=%s hyb=%s rep=%s\nBurn-in: %s\nOutput: %s\nSeed: %s (%s)\n' \
    "$ID" "$SC" "$TI" "$HR" "$REP" "$BURN" "$OUT" "$SEED" "$SEED_ORIGIN"
if (( CHECK_ONLY )); then
    echo 'Preflight passed; no simulation or submission performed.'
    exit 0
fi
mkdir -p "$OUT/status"
# Atomic directory creation prevents duplicate array submissions writing together.
LOCK="$OUT/status/running.lock"
mkdir "$LOCK" 2>/dev/null || fail "Another run owns $LOCK; check it before retrying"
trap 'rmdir "$LOCK"' EXIT
# A corrected result must include the new viable-count columns and a current
# script fingerprint; old v4.5 done markers cannot silently skip this run.
FINGERPRINT=$(sha256sum "$SCRIPT" | cut -d' ' -f1)
CONFIG_FINGERPRINT=$(sha256sum "$CONFIG" | cut -d' ' -f1)
if [[ -s $DONE && -s $CSV ]] && grep -Fq "script_sha256=$FINGERPRINT" "$DONE" && grep -Fq "config_sha256=$CONFIG_FINGERPRINT" "$DONE" && \
    head -n1 "$CSV" | grep -q 'N_viable_p1,N_viable_p2,N_viable_p3' && \
    [[ $(tail -n1 "$CSV" | cut -d, -f1) == "$END" ]]; then
    echo "Already complete with current script: $OUT"; exit 0
fi
rm -f "$DONE"
if [[ $SOURCESEED == NONE ]]; then printf '%s\n' "$SEED" > "$BRANCHSEED"; fi
# Keep the full effective command/config for reproducibility.
ARGS=(); for value in "${PARAMS[@]}"; do ARGS+=(-d "$value"); done
cp "$CONFIG" "$OUT/config_used.yaml"
printf '%q ' slim -s "$SEED" "${ARGS[@]}" "$SCRIPT" > "$OUT/command_used.txt"
printf '\n' >> "$OUT/command_used.txt"
module load "$(cfg slim_module)"
cd "$OUT"
slim -s "$SEED" "${ARGS[@]}" "$SCRIPT" > "$CONSOLE" 2>&1
python3 - "$CSV" "$BURNIN" "$END" <<'PY'
import csv,sys
path,start,end=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
with open(path) as f:
    reader=csv.DictReader(f)
    for expected,row in enumerate(reader,start+1):
        if int(row['Generation']) != expected:
            sys.exit('Non-contiguous generation output')
        for pop in ('p1','p2','p3'):
            if not 0 <= int(row['N_viable_'+pop]) <= int(row['N_'+pop]):
                sys.exit('Invalid viable counts')
    if 'expected' not in locals() or expected != end:
        sys.exit('Incomplete post-burn-in output')
PY
printf 'scenario=%s theta=%s hyb=%s rep=%s generation=%s script_sha256=%s config_sha256=%s\n' \
    "$SC" "$TI" "$HR" "$REP" "$END" "$FINGERPRINT" "$CONFIG_FINGERPRINT" > "$DONE"
echo "Completed: $OUT"
