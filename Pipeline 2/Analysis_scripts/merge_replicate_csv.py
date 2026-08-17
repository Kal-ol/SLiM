#!/usr/bin/env python3
import argparse
import csv
import json
import re
from pathlib import Path


def natural_key(path):
    return [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", str(path))]


def truth(value):
    return bool(value)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--replicate-dir", type=Path, required=True)
    p.add_argument("--parameter-name", required=True)
    p.add_argument("--parameter-value", required=True)
    p.add_argument("--replicate", type=int, required=True)
    p.add_argument("--first-generation", type=int, required=True)
    p.add_argument("--target-generation", type=int, required=True)
    p.add_argument("--full-csv-name", required=True)
    p.add_argument("--section-pattern", required=True)
    p.add_argument("--finished-marker", required=True)
    p.add_argument("--burnin-tree-name", required=True)
    p.add_argument("--final-tree-name", required=True)
    p.add_argument("--merged-output", type=Path, required=True)
    p.add_argument("--qc-output", type=Path, required=True)
    a = p.parse_args()

    repdir = a.replicate_dir.expanduser()
    full = repdir / a.full_csv_name
    sections = sorted(repdir.glob(a.section_pattern), key=natural_key) if repdir.is_dir() else []
    sources = ([full] if full.is_file() else []) + sections
    by_generation = {}
    source_for_generation = {}
    duplicate_count = 0
    conflicting_duplicate_count = 0
    malformed_rows = 0
    headers = []

    for source in sources:
        with source.open(newline="") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames or "Generation" not in reader.fieldnames:
                malformed_rows += 1
                continue
            headers.append(reader.fieldnames)
            for row in reader:
                try:
                    generation = int(row["Generation"])
                except (TypeError, ValueError):
                    malformed_rows += 1
                    continue
                if generation in by_generation:
                    duplicate_count += 1
                    if row != by_generation[generation]:
                        conflicting_duplicate_count += 1
                by_generation[generation] = row
                source_for_generation[generation] = str(source)

    header_consistent = len({tuple(h) for h in headers}) <= 1
    fieldnames = headers[0] if headers else []
    generations = sorted(by_generation)
    expected = set(range(a.first_generation, a.target_generation + 1))
    present_to_target = {g for g in generations if a.first_generation <= g <= a.target_generation}
    missing = sorted(expected - present_to_target)
    reached_target = a.target_generation in by_generation
    csv_complete = reached_target and not missing and header_consistent and conflicting_duplicate_count == 0

    a.merged_output.parent.mkdir(parents=True, exist_ok=True)
    with a.merged_output.open("w", newline="") as handle:
        if fieldnames:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            for generation in generations:
                if generation <= a.target_generation:
                    writer.writerow(by_generation[generation])

    burnin_tree = repdir / a.burnin_tree_name
    final_tree = repdir / a.final_tree_name
    finished = repdir / a.finished_marker
    output_complete = csv_complete and final_tree.is_file() and final_tree.stat().st_size > 0 and finished.is_file()
    if output_complete:
        completion_class = "complete_output_set"
    elif csv_complete and not (final_tree.is_file() and final_tree.stat().st_size > 0):
        completion_class = "csv_complete_missing_final_tree"
    elif csv_complete and not finished.is_file():
        completion_class = "csv_complete_missing_finished_marker"
    elif reached_target:
        completion_class = "reached_target_but_csv_qc_failed"
    elif generations:
        completion_class = "incomplete_csv"
    else:
        completion_class = "missing_csv"
    qc = {
        "parameter_name": a.parameter_name,
        "parameter_value": a.parameter_value,
        "replicate": a.replicate,
        "replicate_directory": str(repdir),
        "source_csv_count": len(sources),
        "section_csv_count": len(sections),
        "full_csv_exists": full.is_file(),
        "first_generation": generations[0] if generations else None,
        "last_generation": generations[-1] if generations else None,
        "unique_generation_count": len(generations),
        "target_generation": a.target_generation,
        "reached_target": reached_target,
        "missing_generation_count": len(missing),
        "missing_generations": missing,
        "duplicate_generation_count": duplicate_count,
        "conflicting_duplicate_count": conflicting_duplicate_count,
        "malformed_row_count": malformed_rows,
        "header_consistent": header_consistent,
        "csv_complete": csv_complete,
        "burnin_tree_exists": burnin_tree.is_file() and burnin_tree.stat().st_size > 0,
        "final_tree_exists": final_tree.is_file() and final_tree.stat().st_size > 0,
        "finished_marker_exists": finished.is_file(),
        "output_complete": output_complete,
        "completion_class": completion_class,
    }
    a.qc_output.parent.mkdir(parents=True, exist_ok=True)
    a.qc_output.write_text(json.dumps(qc, indent=2) + "\n")


if __name__ == "__main__":
    main()
