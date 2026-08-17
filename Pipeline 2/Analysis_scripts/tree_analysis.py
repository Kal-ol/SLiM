#!/usr/bin/env python3
import argparse
import csv
import json
import math
from pathlib import Path


FIELDS = ["parameter_name", "parameter_value", "replicate", "status", "message",
          "region", "statistic", "comparison", "mode", "value",
          "n_p1", "n_p2", "n_p3", "sequence_length", "num_trees",
          "max_roots", "recapitated", "site_mutations"]


def parse_population(value):
    name, pop_id = value.split(":", 1)
    return name, int(pop_id)


def parse_region(value):
    name, start, end = value.split(":", 2)
    return name, (float(start), float(end))


def metadata_name(population):
    metadata = population.metadata
    if isinstance(metadata, bytes):
        try:
            metadata = json.loads(metadata.decode())
        except Exception:
            return None
    if isinstance(metadata, dict):
        return metadata.get("name") or metadata.get("subpopulation_name")
    return None


def scalar(value):
    try:
        return float(value.reshape(-1)[0])
    except AttributeError:
        try:
            return float(value[0])
        except (TypeError, IndexError):
            return float(value)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--replicate-dir", type=Path, required=True)
    p.add_argument("--tree-name", required=True)
    p.add_argument("--parameter-name", required=True)
    p.add_argument("--parameter-value", required=True)
    p.add_argument("--replicate", type=int, required=True)
    p.add_argument("--population", action="append", default=[], type=parse_population)
    p.add_argument("--region", action="append", default=[], type=parse_region)
    p.add_argument("--final-sample-time", type=float, default=0)
    p.add_argument("--neutral-rate", type=float, default=0)
    p.add_argument("--neutral-seed-base", type=int, default=810000)
    p.add_argument("--keep-existing-mutations", action="store_true")
    p.add_argument("--recapitate", action="store_true")
    p.add_argument("--ancestral-ne", type=float)
    p.add_argument("--recombination-rate", type=float)
    p.add_argument("--recapitation-seed-base", type=int, default=820000)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    tree_path = a.replicate_dir / a.tree_name
    a.output.parent.mkdir(parents=True, exist_ok=True)
    if not tree_path.is_file() or tree_path.stat().st_size == 0:
        with a.output.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS); writer.writeheader()
            writer.writerow({"parameter_name": a.parameter_name, "parameter_value": a.parameter_value,
                             "replicate": a.replicate, "status": "missing_tree",
                             "message": str(tree_path)})
        return

    try:
        import numpy as np
        import tskit
        import pyslim
        import msprime

        ts = tskit.load(str(tree_path))
        if a.recapitate:
            if a.ancestral_ne is None or a.recombination_rate is None:
                raise ValueError("Recapitation requires ancestral Ne and recombination rate")
            ts = pyslim.recapitate(
                ts, ancestral_Ne=a.ancestral_ne,
                recombination_rate=a.recombination_rate,
                random_seed=a.recapitation_seed_base + a.replicate,
            )

        configured = dict(a.population)
        resolved = {}
        for pop_id, pop in enumerate(ts.populations()):
            name = metadata_name(pop)
            if name in configured:
                resolved[name] = pop_id
        for name, fallback in configured.items():
            if name not in resolved and 0 <= fallback < ts.num_populations:
                resolved[name] = fallback

        samples = {}
        all_samples = ts.samples()
        for name in configured:
            if name not in resolved:
                samples[name] = []
                continue
            candidates = ts.samples(population=resolved[name])
            samples[name] = [u for u in candidates if math.isclose(ts.node(u).time, a.final_sample_time, abs_tol=1e-9)]

        site_ts = ts
        if a.neutral_rate > 0:
            site_ts = msprime.sim_mutations(
                ts, rate=a.neutral_rate,
                random_seed=a.neutral_seed_base + a.replicate,
                keep=a.keep_existing_mutations,
                model=msprime.SLiMMutationModel(type=0),
            )

        rows = []
        counts = {f"n_{name}": len(nodes) for name, nodes in samples.items()}
        diagnostics = {
            "sequence_length": ts.sequence_length,
            "num_trees": ts.num_trees,
            "max_roots": max((tree.num_roots for tree in ts.trees()), default=0),
            "recapitated": a.recapitate,
            "site_mutations": site_ts.num_mutations,
        }
        for region_name, (start, end) in a.region:
            if not (0 <= start < end <= ts.sequence_length):
                raise ValueError(f"Region {region_name} [{start}, {end}) is outside sequence length {ts.sequence_length}")
            windows = [start, end]
            for name, nodes in samples.items():
                if len(nodes) < 2:
                    continue
                for mode, source in (("site", site_ts), ("branch", ts)):
                    value = scalar(source.diversity([nodes], windows=windows, mode=mode))
                    rows.append({"region": region_name, "statistic": "diversity",
                                 "comparison": name, "mode": mode, "value": value})
            names = list(samples)
            for i, left in enumerate(names):
                for right in names[i + 1:]:
                    if not samples[left] or not samples[right]:
                        continue
                    for mode, source in (("site", site_ts), ("branch", ts)):
                        sets = [samples[left], samples[right]]
                        divergence = scalar(source.divergence(sets, indexes=[(0, 1)], windows=windows, mode=mode))
                        fst = scalar(source.Fst(sets, windows=windows, mode=mode))
                        comparison = f"{left}_vs_{right}"
                        rows.append({"region": region_name, "statistic": "divergence",
                                     "comparison": comparison, "mode": mode, "value": divergence})
                        rows.append({"region": region_name, "statistic": "Fst",
                                     "comparison": comparison, "mode": mode, "value": fst})

        with a.output.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS); writer.writeheader()
            for row in rows:
                writer.writerow({"parameter_name": a.parameter_name, "parameter_value": a.parameter_value,
                                 "replicate": a.replicate, "status": "ok", "message": "",
                                 **row, **counts, **diagnostics})
    except Exception as exc:
        with a.output.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS); writer.writeheader()
            writer.writerow({"parameter_name": a.parameter_name, "parameter_value": a.parameter_value,
                             "replicate": a.replicate, "status": "error",
                             "message": f"{type(exc).__name__}: {exc}"})
        raise


if __name__ == "__main__":
    main()
