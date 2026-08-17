#!/usr/bin/env python3
import argparse
import csv
import json
from collections import Counter
from pathlib import Path


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--qc-root", type=Path, required=True)
    p.add_argument("--audit-output", type=Path, required=True)
    p.add_argument("--summary-output", type=Path, required=True)
    a = p.parse_args()

    records = [json.loads(path.read_text()) for path in sorted(a.qc_root.rglob("rep*.json"))]
    if not records:
        raise SystemExit(f"No replicate QC files found under {a.qc_root}")
    for record in records:
        record["missing_generations"] = ";".join(map(str, record["missing_generations"]))

    a.audit_output.parent.mkdir(parents=True, exist_ok=True)
    with a.audit_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)

    group_fields = ["reached_target", "csv_complete", "final_tree_exists", "finished_marker_exists", "output_complete"]
    grouped = {}
    for record in records:
        key = (record["parameter_name"], record["parameter_value"])
        grouped.setdefault(key, []).append(record)
    rows = []
    for (parameter, value), group in sorted(grouped.items()):
        row = {"parameter_name": parameter, "parameter_value": value, "total_replicates": len(group)}
        for field in group_fields:
            row[field] = sum(bool(record[field]) for record in group)
        classes = Counter(record["completion_class"] for record in group)
        for name in sorted({record["completion_class"] for record in records}):
            row[name] = classes.get(name, 0)
        rows.append(row)
    summary_fields = list(dict.fromkeys(field for row in rows for field in row))
    with a.summary_output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=summary_fields)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
