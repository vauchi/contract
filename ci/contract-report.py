#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Catalog the emitted contract schema; report growth and reviewed feature impact."""

import argparse
from collections import Counter
from datetime import date
import hashlib
import html
import json
from pathlib import Path
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
STATES = ("unchanged", "required", "unknown")
ANNOTATIONS = {"description", "title", "examples", "$comment"}


def read_json(path):
    raw = Path(path).read_bytes()
    try:
        return json.loads(raw), raw
    except (ValueError, UnicodeError) as error:
        raise ValueError(f"invalid JSON in {path}: {error}") from error


def variants(node, *, envelopes=False):
    result = {}
    for arm in node["oneOf"]:
        if isinstance(arm, dict) and isinstance(arm.get("enum"), list):
            entries = [(tag, {"enum": [tag]}) for tag in arm["enum"]]
        elif isinstance(arm, dict) and len(arm.get("properties", {})) == 1:
            entries = list(arm["properties"].items())
        else:
            raise ValueError("invalid contract schema: unrecognized union arm")
        for tag, body in entries:
            if not isinstance(tag, str) or not tag or tag in result:
                raise ValueError("invalid contract schema: empty or duplicate variant")
            if not isinstance(body, dict):
                raise ValueError("invalid contract schema: variant payload must be an object schema")
            if envelopes:
                result[tag] = arm | {"enum": [tag]} if "enum" in arm else arm
            else:
                result[tag] = body
    if not result:
        raise ValueError("invalid contract schema: empty union")
    return result


def inventory(schema):
    if not isinstance(schema, dict) or schema.get("schema_version") != 1:
        raise ValueError("invalid contract schema: expected schema_version 1")
    entries, counts, names = {}, {}, set()
    for root in ("command", "event"):
        node = schema.get(root)
        if not isinstance(node, dict) or not isinstance(node.get("oneOf"), list):
            raise ValueError(f"invalid contract schema: missing {root} union")
        arms = variants(node)
        counts[f"{root}_variants"] = len(arms)
        entries.update({f"{root}.{name}": value for name, value in variants(node, envelopes=True).items()})
        definitions = node.get("definitions", {})
        if not isinstance(definitions, dict):
            raise ValueError("invalid contract schema: definitions must be an object")
        names.update(definitions)
        entries.update({f"{root}.definitions.{name}": value for name, value in definitions.items()})
    counts["definition_names"] = len(names)
    counts["definition_declarations"] = sum(".definitions." in name for name in entries)
    return entries, counts


def semantic(value):
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            if key in ANNOTATIONS:
                continue
            if key in ("properties", "definitions", "$defs", "patternProperties", "dependentSchemas"):
                result[key] = {name: semantic(body) for name, body in item.items()}
            elif key in ("default", "const"):
                result[key] = item
            elif key in ("enum", "required"):
                result[key] = sorted(item, key=lambda entry: json.dumps(entry, sort_keys=True))
            elif key in ("oneOf", "anyOf", "allOf"):
                result[key] = sorted((semantic(entry) for entry in item),
                                     key=lambda entry: json.dumps(entry, sort_keys=True))
            else:
                result[key] = semantic(item)
        return result
    if isinstance(value, list):
        return [semantic(item) for item in value]
    return value


def parse_day(value):
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() == value:
            return parsed
    except (TypeError, ValueError):
        pass
    raise ValueError("invalid feature impact: dates must use a valid YYYY-MM-DD")


def feature_impact(path, since=None):
    document, _ = read_json(path)
    if not isinstance(document, dict) or document.get("version") != 1 or not isinstance(document.get("changes"), list):
        raise ValueError("invalid feature impact: expected version 1 and changes array")
    all_changes, seen, changes = document["changes"], set(), []
    counts, releases = Counter(), Counter()
    by_shell = {}
    undated, outside_window = 0, 0
    start = parse_day(since) if since is not None else None
    for change in all_changes:
        if not isinstance(change, dict):
            raise ValueError("invalid feature impact: observation must be an object")
        for key in ("id", "evidence", "reason"):
            if not isinstance(change.get(key), str) or not change[key].strip():
                raise ValueError(f"invalid feature impact: {key} is required")
        if change["id"] in seen:
            raise ValueError("invalid feature impact: duplicate id")
        seen.add(change["id"])
        evidence = urlsplit(change["evidence"])
        state = change.get("shell_behavior")
        release = change.get("contract_release", "unknown")
        shells = change.get("shells")
        if evidence.scheme != "https" or not evidence.netloc:
            raise ValueError("invalid feature impact: evidence must be an HTTPS link")
        if state not in STATES or release not in STATES:
            raise ValueError("invalid feature impact: unsupported classification")
        if not isinstance(shells, list) or any(not isinstance(s, str) or not s.strip() for s in shells):
            raise ValueError("invalid feature impact: shells must be an array of names")
        if len(shells) != len(set(shells)):
            raise ValueError("invalid feature impact: duplicate affected shell")
        if state == "required" and not shells:
            raise ValueError("invalid feature impact: required behavior must name affected shells")
        if state == "unchanged" and shells:
            raise ValueError("invalid feature impact: unchanged behavior must have no affected shells")
        observed = parse_day(change["observed_on"]) if "observed_on" in change else None
        undated += observed is None
        if start is not None and observed is not None and observed < start:
            outside_window += 1
            continue
        if start is not None and observed is None:
            continue
        changes.append(change)
        counts[state] += 1
        releases[release] += 1
        for shell in shells:
            by_shell.setdefault(shell, {"required": 0, "unknown": 0})[state] += 1
    known = counts["unchanged"] + counts["required"]
    recorded = len(changes)
    return {
        "recorded": recorded, "known": known,
        **{state: counts[state] for state in STATES},
        "required_share_of_known": counts["required"] / known if known else None,
        "known_share_of_recorded": known / recorded if recorded else None,
        "required_share_of_recorded_bounds": {
            "lower": counts["required"] / recorded,
            "upper": (counts["required"] + counts["unknown"]) / recorded,
        } if recorded else None,
        "window": {"since": since, "total_recorded": len(all_changes),
                   "undated": undated, "outside_window": outside_window},
        "by_shell": dict(sorted(by_shell.items())),
        "contract_release": {state: releases[state] for state in STATES},
        "changes": changes,
    }


def fixture_inventory(directory):
    if not directory.is_dir():
        raise ValueError(f"fixture directory is missing: {directory}")
    files = {}
    for path in sorted(directory.glob("*.json")):
        raw = path.read_bytes()
        files[path.name] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    return files


def fixture_report(directory, baseline):
    files = fixture_inventory(directory)
    changes = None
    previous = fixture_inventory(baseline) if baseline else None
    if previous is not None:
        changes = {"added": sorted(files.keys() - previous.keys()),
                   "removed": sorted(previous.keys() - files.keys()),
                   "changed": sorted(name for name in files.keys() & previous.keys()
                                     if files[name] != previous[name])}
    size = sum(item["bytes"] for item in files.values())
    return {"files": files, "bytes": size, "changes": changes,
            "bytes_delta": size - sum(item["bytes"] for item in previous.values())
            if previous is not None else None}


def report(schema, raw, impacts, baseline, fixtures, baseline_fixtures, since):
    entries, counts = inventory(schema)
    growth = None
    if baseline:
        old, old_raw = read_json(baseline)
        previous, old_counts = inventory(old)
        growth = {
            "baseline_sha256": hashlib.sha256(old_raw).hexdigest(),
            "counts": {name: count - old_counts[name] for name, count in counts.items()},
            "added": sorted(entries.keys() - previous.keys()),
            "removed": sorted(previous.keys() - entries.keys()),
            "changed": sorted(name for name in entries.keys() & previous.keys()
                              if semantic(entries[name]) != semantic(previous[name])),
            "envelopes_changed": [root for root in ("command", "event") if semantic({
                key: value for key, value in old[root].items() if key not in ("oneOf", "definitions")
            }) != semantic({
                key: value for key, value in schema[root].items() if key not in ("oneOf", "definitions")
            })],
        }
    return {"schema_sha256": hashlib.sha256(raw).hexdigest(), "schema_bytes": len(raw),
            "counts": counts, "growth": growth, "feature_impact": feature_impact(impacts, since),
            "fixtures": fixture_report(fixtures, baseline_fixtures)}


def code(value):
    text = html.escape(str(value), quote=False).replace("|", "&#124;")
    return "`" + text.replace("`", "&#96;").replace("\n", " ").replace("\r", " ") + "`"


def compact(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def declaration_lines(body):
    if not isinstance(body, dict) or not body.get("properties"):
        raw = json.dumps(body, sort_keys=True, ensure_ascii=False, indent=2)
        return ["```json", raw.replace("<", "\\u003c").replace(">", "\\u003e"), "```", ""]
    lines = ["| Field | Required | Schema |", "| --- | --- | --- |"]
    expanded = []
    for field, value in sorted(body["properties"].items()):
        required = "yes" if field in body.get("required", []) else "no"
        fragment = {key: item for key, item in value.items() if key not in ANNOTATIONS}
        rendered = code(compact(fragment))
        if len(rendered) > 700:
            expanded += [f"Field {code(field)}:", "", *declaration_lines(fragment)]
            rendered = "expanded below"
        lines.append(f"| {code(field)} | {required} | {rendered} |")
    return lines + ["", *expanded]


def catalog_markdown(schema):
    inventory(schema)
    lines = [
        "<!-- SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me> -->",
        "<!-- SPDX-" + "License-Identifier: AGPL-3.0-or-later -->", "",
        "# Contract vocabulary", "",
        "Generated by `ci/contract-report.py`; edit the canonical types, then regenerate.", "",
        "Fields below reproduce schema declarations; references are not expanded.",
        "Schema defaults are annotations, not a guarantee of native decoder behavior.",
        "Custom Rust validation and renderer behavior require separate conformance tests.", "",
    ]
    for root in ("command", "event"):
        lines += [f"## {root.title()} variants", "", "| Variant | Payload schema |", "| --- | --- |"]
        for name, body in sorted(variants(schema[root]).items()):
            fields = body.get("properties", {})
            if fields:
                payload = ", ".join(code(field) for field in sorted(fields))
            elif "enum" in body:
                payload = "wire string"
            else:
                payload = code(compact(body)) if len(compact(body)) < 700 else "expanded below"
            lines.append(f"| {code(name)} | {payload} |")
        lines.append("")
        for name, body in sorted(variants(schema[root]).items()):
            if "enum" not in body:
                lines += [f"### {code(root + '.' + name)}", "", *declaration_lines(body)]
        lines += ["", f"## {root.title()} supporting types", ""]
        for name, body in sorted(schema[root].get("definitions", {}).items()):
            lines += [f"### {code(root + '.' + name)}", "", *declaration_lines(body)]
    return "\n".join(lines).replace("\n\n\n", "\n\n")


def report_markdown(result):
    lines = ["# Contract evolution report", "", "## Schema measurements", "",
             f"Schema SHA-256: {code(result['schema_sha256'])}", "",
             f"Schema file bytes: {result['schema_bytes']} (not a wire payload or binary size).", "",
             "| Measure | Current | Delta |", "| --- | ---: | ---: |"]
    growth = result["growth"]
    for name, count in result["counts"].items():
        delta = f"{growth['counts'][name]:+d}" if growth is not None else "not measured"
        lines.append(f"| {name} | {count} | {delta} |")
    lines += ["", "Definition names are deduplicated by name; declarations retain each root.", "",
              "## Vocabulary changes", ""]
    if growth is None:
        lines += ["No baseline supplied; growth is not measured.", ""]
    else:
        for kind in ("added", "removed", "changed", "envelopes_changed"):
            lines.append(f"- {kind.title()}: " + (", ".join(code(x) for x in growth[kind]) or "none"))
        lines += ["", "Changes are structural observations, not compatibility verdicts.", ""]
    fixtures = result["fixtures"]
    fixture_delta = "not measured" if fixtures["bytes_delta"] is None else f"{fixtures['bytes_delta']:+d}"
    lines += ["## Fixture files", "",
              f"Top-level JSON file bytes: {fixtures['bytes']}; delta: {fixture_delta}.", "",
              "File sizes are not wire payloads, render cost or final binary sizes.", "",
              "Fixture churn does not establish a protocol or shell-behavior change.", "",
              "| File | Bytes | SHA-256 |", "| --- | ---: | --- |"]
    for name, item in fixtures["files"].items():
        lines.append(f"| {code(name)} | {item['bytes']} | {code(item['sha256'])} |")
    lines.append("")
    if fixtures["changes"] is None:
        lines += ["No fixture baseline supplied; fixture churn is not measured.", ""]
    else:
        for kind, names in fixtures["changes"].items():
            lines.append(f"- {kind.title()}: " + (", ".join(code(name) for name in names) or "none"))
        lines.append("")
    impact = result["feature_impact"]
    share = impact["required_share_of_known"]
    ratio = "not measured" if share is None else f"{impact['required']}/{impact['known']} ({share:.1%})"
    window = impact["window"]
    bounds = impact["required_share_of_recorded_bounds"]
    bounds_text = "not measured" if bounds is None else f"{bounds['lower']:.1%} to {bounds['upper']:.1%}"
    lines += ["## Reviewed feature impact", "",
              "Scope: recorded changes only; unrecorded features are not counted.", "",
              "Review window: " + (f"since {code(window['since'])}, inclusive."
                                    if window["since"] else "all dates."), "",
              f"All observations: {window['total_recorded']}; undated: {window['undated']}; "
              f"outside window: {window['outside_window']}.", "",
              "Undated entries are excluded from dated windows; otherwise they are included.", "",
              f"Known: {impact['known']}/{impact['recorded']}; unknown shell impact: {impact['unknown']}.", "",
              f"New shell behavior among known observations: {ratio}.", "",
              f"Possible required share among selected observations: {bounds_text}.", "",
              "Bounds reflect unresolved classifications, not statistical confidence.", "",
              "Contract-package release declarations: " + ", ".join(
                  f"{state}: {count}" for state, count in impact["contract_release"].items()) + ".", "",
              "Reviewer declarations link to evidence; schema size does not establish impact.", "",
              "| Change | Observed on | Shell behavior | Contract release | Affected shells | Reason | Evidence |",
              "| --- | --- | --- | --- | --- | --- | --- |"]
    for change in impact["changes"]:
        values = (change["id"], change.get("observed_on", "undated"),
                  change["shell_behavior"], change.get("contract_release", "unknown"),
                  ", ".join(change["shells"]) or "none declared", change["reason"], change["evidence"])
        lines.append("| " + " | ".join(code(value) for value in values) + " |")
    lines += ["", "## Affected shells", "",
              "Counts describe required or suspected work, not completion or effort.", "",
              "| Shell | Required observations | Unknown observations |", "| --- | ---: | ---: |"]
    for shell, counts in impact["by_shell"].items():
        lines.append(f"| {code(shell)} | {counts['required']} | {counts['unknown']} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("catalog", "report"))
    parser.add_argument("schema", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--impacts", type=Path, default=ROOT / "review/feature-impact.json")
    parser.add_argument("--fixtures", type=Path, default=ROOT / "fixtures")
    parser.add_argument("--baseline-fixtures", type=Path)
    parser.add_argument("--since", help="include feature reviews observed on or after YYYY-MM-DD")
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    destination = parser.add_mutually_exclusive_group()
    destination.add_argument("--output", type=Path)
    destination.add_argument("--check", type=Path)
    args = parser.parse_args()
    try:
        schema, raw = read_json(args.schema)
        if args.mode == "catalog":
            output = catalog_markdown(schema)
        else:
            result = report(schema, raw, args.impacts, args.baseline, args.fixtures, args.baseline_fixtures, args.since)
            output = json.dumps(result, indent=2, ensure_ascii=False) + "\n" if args.format == "json" else report_markdown(result)
        if args.check:
            if not args.check.is_file() or args.check.read_text(encoding="utf-8") != output:
                print("catalog is stale; regenerate with --output", file=sys.stderr)
                return 1
            print("catalog is current")
        elif args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(output, encoding="utf-8")
        else:
            print(output, end="")
        return 0
    except (ValueError, OSError, TypeError, KeyError, RecursionError) as error:
        print(f"contract report: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
