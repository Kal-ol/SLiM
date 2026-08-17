#!/usr/bin/env python3
import argparse
import csv
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


IDENTITY = {"Generation", "Phase", "EnvScenario"}


def describe(values):
    return {
        "n": len(values),
        "mean": statistics.fmean(values) if values else "",
        "sd": statistics.stdev(values) if len(values) > 1 else (0.0 if values else ""),
        "min": min(values) if values else "",
        "max": max(values) if values else "",
        "median": statistics.median(values) if values else "",
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--analysis-root", type=Path, required=True)
    p.add_argument("--eligibility-field", required=True)
    p.add_argument("--target-generation", type=int, required=True)
    p.add_argument("--replicate-output", type=Path, required=True)
    p.add_argument("--endpoint-output", type=Path, required=True)
    p.add_argument("--trajectory-output", type=Path, required=True)
    a = p.parse_args()

    qc_files = sorted((a.analysis_root / "qc").rglob("rep*.json"))
    trajectory = defaultdict(lambda: defaultdict(list))
    endpoints = []
    numeric_columns = None

    for qc_path in qc_files:
        qc = json.loads(qc_path.read_text())
        if a.eligibility_field not in qc:
            raise SystemExit(f"Unknown eligibility field: {a.eligibility_field}")
        if not qc[a.eligibility_field]:
            continue
        merged = a.analysis_root / "merged" / f'{qc["parameter_name"]}_{qc["parameter_value"]}' / f'rep{qc["replicate"]}.csv'
        with merged.open(newline="") as handle:
            reader = csv.DictReader(handle)
            if numeric_columns is None:
                numeric_columns = [name for name in reader.fieldnames if name not in IDENTITY]
            endpoint = None
            for row in reader:
                generation = int(row["Generation"])
                key = (qc["parameter_name"], qc["parameter_value"], generation, row["Phase"], row["EnvScenario"])
                for column in numeric_columns:
                    try:
                        value = float(row[column])
                        if math.isfinite(value):
                            trajectory[key][column].append(value)
                    except (TypeError, ValueError):
                        pass
                if generation == a.target_generation:
                    endpoint = row
            if endpoint is None:
                continue
            out = {
                "parameter_name": qc["parameter_name"],
                "parameter_value": qc["parameter_value"],
                "replicate": qc["replicate"],
                "Generation": a.target_generation,
            }
            out.update({column: endpoint[column] for column in numeric_columns})
            endpoints.append(out)

    if not endpoints or numeric_columns is None:
        raise SystemExit("No eligible population replicates were found")

    a.replicate_output.parent.mkdir(parents=True, exist_ok=True)
    with a.replicate_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(endpoints[0]))
        writer.writeheader(); writer.writerows(endpoints)

    grouped_endpoint = defaultdict(lambda: defaultdict(list))
    for row in endpoints:
        key = (row["parameter_name"], row["parameter_value"])
        for column in numeric_columns:
            try:
                grouped_endpoint[key][column].append(float(row[column]))
            except (TypeError, ValueError):
                pass
    endpoint_rows = []
    for (parameter, value), columns in sorted(grouped_endpoint.items()):
        for column in numeric_columns:
            endpoint_rows.append({
                "parameter_name": parameter, "parameter_value": value,
                "Generation": a.target_generation, "variable": column,
                **describe(columns[column]),
            })
    with a.endpoint_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(endpoint_rows[0]))
        writer.writeheader(); writer.writerows(endpoint_rows)

    trajectory_rows = []
    for (parameter, value, generation, phase, scenario), columns in sorted(trajectory.items()):
        for column in numeric_columns:
            trajectory_rows.append({
                "parameter_name": parameter, "parameter_value": value,
                "Generation": generation, "Phase": phase, "EnvScenario": scenario,
                "variable": column, **describe(columns[column]),
            })
    with a.trajectory_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(trajectory_rows[0]))
        writer.writeheader(); writer.writerows(trajectory_rows)


if __name__ == "__main__":
    main()

