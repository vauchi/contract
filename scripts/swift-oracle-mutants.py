#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Derive rejected and boundary messages from the accepted ones.

The hand-written cases cover the rules somebody thought of. This walks
every message of `cases.jsonl` and `corpus.jsonl` and changes one value
at a time: each string, number, array and object, at every place a
message shape has one. The Rust decoder then says which changed messages
it still accepts, and a generated product has to agree on each.

One message per shape and change is kept, the smallest, so a field that
recurs in every catalog screen is probed once.
"""

import copy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
oracle = root / "cache/oracle"

# One past the powers of two a byte or item bound usually sits on, and the
# value itself, so a bound is met from both sides.
LENGTHS = [32, 33, 64, 65, 128, 129, 256, 257, 512, 513, 1024, 1025, 2048, 2049, 4096, 4097, 8192, 8193]
ITEM_COUNTS = [2, 3, 4, 5, 8, 9, 16, 17, 32, 33, 64, 65, 128, 129, 256, 257]
NUMBERS = [-1, 0, 1, 255, 256, 65535, 65536, 2**31, 2**32 - 1, 2**32, 2**63, 2**64 - 1, 2**64, 0.5, 1e400]
ABSENT = object()


def string_changes(value):
    yield "empty", ""
    yield "control", value + "\u0001"
    yield "delete", value + "\u007f"
    yield "c1_control", value + "\u0085"
    yield "newline", "a\nb"
    yield "nul", "a\u0000b"
    for length in LENGTHS:
        yield f"ascii_{length}", "x" * length
        # Two bytes each: tells a byte bound from a character bound.
        yield f"two_byte_{length}", "é" * length
    yield "number", 1
    yield "null", None


def number_changes(_value):
    for number in NUMBERS:
        yield f"number_{number}", number
    yield "string", "1"
    yield "null", None


def array_changes(value):
    yield "no_items", []
    yield "null", None
    yield "object", {}
    if value:
        for count in ITEM_COUNTS:
            yield f"items_{count}", [value[0]] * count


def object_changes(value):
    yield "null", None
    yield "array", []
    yield "unknown_key", {**value, "zz_unknown": 1}
    for key in value:
        yield f"without_{key}", {k: v for k, v in value.items() if k != key}
    if len(value) == 1:
        (key, inner), = value.items()
        yield "second_tag", {key: inner, "zz_unknown": inner}


# (size, x, y): a rule across fields, which one change at a time never meets.
# The code's side is 500 to 1000 and it stays inside a square of 1000.
PLACEMENTS = [
    (500, 0, 0), (500, 500, 500), (500, 501, 0), (500, 0, 501), (499, 0, 0),
    (1000, 0, 0), (1000, 1, 0), (1000, 0, 1), (1001, 0, 0), (750, 250, 250),
    (750, 251, 250), (750, 250, 251),
]


def is_placement(value):
    return isinstance(value, dict) and set(value) == {"size", "x", "y"}


def changes(value):
    if is_placement(value):
        return [
            *object_changes(value),
            *((f"placement_{size}_{x}_{y}", {"size": size, "x": x, "y": y}) for size, x, y in PLACEMENTS),
        ]
    if isinstance(value, bool):
        return [("string", "true"), ("number", 1), ("null", None)]
    if isinstance(value, str):
        return string_changes(value)
    if isinstance(value, (int, float)):
        return number_changes(value)
    if isinstance(value, list):
        return array_changes(value)
    if isinstance(value, dict):
        return object_changes(value)
    return [("string", "x"), ("number", 1), ("object", {}), ("no_items", [])]


def places(value, path=()):
    """Every value in a message with the keys and positions leading to it."""
    yield path, value
    if isinstance(value, dict):
        for key, inner in value.items():
            yield from places(inner, path + (key,))
    elif isinstance(value, list):
        for index, inner in enumerate(value):
            yield from places(inner, path + (index,))


def replaced(message, path, new):
    if not path:
        return new
    changed = copy.copy(message)
    changed[path[0]] = replaced(message[path[0]], path[1:], new)
    return changed


def shape(path):
    return "/".join("*" if isinstance(step, int) else step for step in path)


bases = []
for name in ["cases", "corpus"]:
    for line in (oracle / f"{name}.jsonl").read_text(encoding="utf-8").splitlines():
        case = json.loads(line)
        if case["kind"] not in ("command", "event"):
            continue
        try:
            bases.append((len(case["json"]), case["kind"], json.loads(case["json"])))
        except json.JSONDecodeError:
            continue
# Smallest first: the first message seen for a shape is the one kept.
bases.sort(key=lambda base: base[0])

seen = set()
cases = []
for _, kind, message in bases:
    for path, value in places(message):
        for label, new in changes(value):
            key = (kind, shape(path), type(value).__name__, label)
            if key in seen:
                continue
            seen.add(key)
            cases.append({
                "id": f"{kind}:{shape(path) or '.'}:{label}",
                "kind": kind,
                "json": json.dumps(replaced(message, path, new)),
            })

ids = [case["id"] for case in cases]
duplicates = len(ids) - len(set(ids))
if duplicates:
    # A string and a number at one place share labels such as `null`.
    counts = {}
    for case in cases:
        counts[case["id"]] = counts.get(case["id"], 0) + 1
        if counts[case["id"]] > 1:
            case["id"] += f"#{counts[case['id']]}"

output = oracle / "mutants.jsonl"
output.write_text(
    "".join(json.dumps(case) + "\n" for case in cases),
    encoding="utf-8",
    newline="\n",
)
print(f"{len(cases)} changed messages")
