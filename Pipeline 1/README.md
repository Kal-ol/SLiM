# SLiM Sectioned Pipeline

Sectioned SLiM simulation pipeline for Slurm.

## Files

* `06_22_2026_model.SLIM` — SLiM model
* `INPUT_1.yaml` — run settings
* `run_snakemake_facilitate.sh` — submits all sections
* `run_section_control.sh` — runs one section and writes checkpoints

## Run

```bash
bash run_snakemake_facilitate.sh
```

## Test one section

```bash
sbatch --array=1-1 run_section_control.sh INPUT_1.yaml 500
```

## Success check

Successful sections print:

```text
checkpoint_bin=1
checkpoint_seed=1
```

Outputs are saved under `results/`.

