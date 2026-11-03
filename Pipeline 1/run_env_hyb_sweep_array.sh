#!/bin/bash
set -euo pipefail
CHECK_ONLY=0
if [[ ${1:-} == --check ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check] CONFIG.yaml" >&2; exit 1; }
CONFIG=$(realpath -e "$1")
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
BASE=$(realpath -e "$(cfg base)")
CONTROL=$(realpath -e "$(cfg control_script)")
SPEC=$(cfg array_spec)
# Validate the array and check every selected source burn-in before submission.
FIRST=$(python3 - "$CONFIG" <<'PYCHECK'
import ast,pathlib,re,sys
config={}
for line in open(sys.argv[1]):
    m=re.match(r'^([A-Za-z_][A-Za-z_0-9]*):\s*(.*?)\s*$',line)
    if m:
        v=m[2]
        config[m[1]]=ast.literal_eval(v) if v.startswith(('"',"'")) else v.split(' #',1)[0].strip()
c=config
spec=c['array_spec']; parts=spec.split('%')
if len(parts)>2 or (len(parts)==2 and (not parts[1].isdigit() or int(parts[1])<1)):
    sys.exit('Invalid array concurrency')
ids=[]
for term in parts[0].split(','):
    if not re.fullmatch(r'[1-9][0-9]*(?:-[1-9][0-9]*)?',term):
        sys.exit('Invalid array specification')
    nums=list(map(int,term.split('-')))
    if len(nums)==2 and nums[0]>nums[1]: sys.exit('Reversed array range')
    ids.extend(range(nums[0],nums[-1]+1))
if len(ids)!=len(set(ids)): sys.exit('Duplicate task IDs')
reps=int(c['total_reps']); z1=c['theta1_z1_values'].split(); z2=c['theta1_z2_values'].split()
nh=len(c['hyb_rates'].split()); ns=len(c['scenarios'].split())
if reps<1 or not nh or not ns or len(z1)!=1 or len(z2)!=1: sys.exit('This full sweep requires one divergent burn-in configuration')
total=reps*len(z1)*nh*ns
if min(ids)<1 or max(ids)>total: sys.exit('Array exceeds treatment grid')
burnin=int(c.get('burnin',2000)); base=pathlib.Path(c['base'])/'results'/c['burnin_result_name']
def groupdir(group):
    subdir=c[group+'_burnin_subdir']
    if subdir!='AUTO': return base/subdir
    parent=base/'annual_base'/'burnin'; found=[]
    target=(float(c['same_env_theta1_z1']),float(c['same_env_theta1_z2']))
    if parent.is_dir():
        for p in parent.iterdir():
            m=re.fullmatch(r'theta1_z1_([^_]+)_z2_([^_]+)',p.name)
            if m and p.is_dir() and tuple(map(float,m.groups()))==target: found.append(p)
    if len(found)!=1: sys.exit('Set same_env_burnin_subdir to its actual path; AUTO could not resolve one group.')
    return found[0]
groups={}; seen=set(); errors=[]
for task in ids:
    combo=(task-1)//reps; ti=combo//(nh*ns); si=(combo%(nh*ns))//nh
    rep=(task-1)%reps+1
    scenario=c['scenarios'].split()[si]
    group='same_env' if scenario=='same_env' else 'divergent'
    if group not in groups:
        groups[group]=groupdir(group)
        print(group+' source: '+str(groups[group]),file=sys.stderr)
    if (group,ti,rep) in seen: continue
    seen.add((group,ti,rep))
    d=groups[group]/f'rep{rep}' 
    for name in (f'burnin_gen{burnin}.bin','phenotype_effects.csv','status/finished.done'):
        p=d/name
        if not p.is_file() or p.stat().st_size==0: errors.append(str(p))
if errors:
    sys.exit('Missing/incomplete selected burn-ins:\n'+'\n'.join(errors))
print(f'Checked {len(ids)} selected tasks / {total} grid tasks; {len(seen)} source burn-ins.',file=sys.stderr)
print(min(ids))
PYCHECK
)
SLURM_ARRAY_TASK_ID="$FIRST" bash "$CONTROL" --check "$CONFIG"
if (( CHECK_ONLY )); then
    echo "Array preflight passed; no jobs submitted. Array: $SPEC"
    exit 0
fi
mkdir -p "$BASE/logs"
ARGS=(--job-name=slim_env_hyb_corrected --nodes=1 --ntasks=1
    --account="$(cfg slurm_account)" --partition="$(cfg slurm_partition)"
    --time="$(cfg time)" --mem="$(cfg mem)" --cpus-per-task="$(cfg cpus_per_task)"
    --array="$SPEC" --output="$BASE/logs/%x_%A_%a.out" --error="$BASE/logs/%x_%A_%a.err")
QOS=$(cfg slurm_qos "")
[[ -z $QOS ]] || ARGS+=(--qos="$QOS")
sbatch "${ARGS[@]}" "$CONTROL" "$CONFIG"
