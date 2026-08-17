#!/usr/bin/env python3
import argparse
import csv
import math
import statistics
from collections import defaultdict
from pathlib import Path


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tree-results-root", type=Path, required=True)
    p.add_argument("--combined-output", type=Path, required=True)
    p.add_argument("--summary-output", type=Path, required=True)
    a = p.parse_args()

    rows = []
    for path in sorted(a.tree_results_root.rglob("rep*.csv")):
        with path.open(newline="") as handle:
            rows.extend(csv.DictReader(handle))
    if not rows:
        raise SystemExit(f"No per-replicate tree results under {a.tree_results_root}")

    a.combined_output.parent.mkdir(parents=True, exist_ok=True)
    with a.combined_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)

    grouped = defaultdict(list)
    for row in rows:
        if row["status"] != "ok" or row["value"] == "":
            continue
        key = (row["parameter_name"], row["parameter_value"], row["region"],
               row["statistic"], row["comparison"], row["mode"])
        value = float(row["value"])
        if math.isfinite(value):
            grouped[key].append(value)
    summary = []
    for key, values in sorted(grouped.items()):
        summary.append({
            "parameter_name": key[0], "parameter_value": key[1], "region": key[2],
            "statistic": key[3], "comparison": key[4], "mode": key[5],
            "n_replicates": len(values), "mean": statistics.fmean(values),
            "sd": statistics.stdev(values) if len(values) > 1 else 0.0,
            "min": min(values), "max": max(values), "median": statistics.median(values),
        })
    if not summary:
        summary = [{"parameter_name": "", "parameter_value": "", "region": "",
                    "statistic": "", "comparison": "", "mode": "", "n_replicates": 0,
                    "mean": "", "sd": "", "min": "", "max": "", "median": ""}]
    with a.summary_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summary[0]))
        writer.writeheader(); writer.writerows(summary)


if __name__ == "__main__":
    main()
