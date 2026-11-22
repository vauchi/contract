#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Derive rejected and boundary messages from the accepted ones.

The hand-written cases cover the rules somebody thought of. This walks
every message of `cases.jsonl` and `corpus.jsonl` that Rust accepts and
changes one value at a time: each string, number, array and object, at
every place a message shape has one. The Rust decoder then says which
changed messages it still accepts, and a generated product has to agree
on each.

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
ITEM_COUNTS = [1, 2, 3, 4, 5, 8, 9, 15, 16, 17, 31, 32, 33, 64, 65, 128, 129, 256, 257]
NUMBERS = [-1, 0, 1, 255, 256, 65535, 65536, 2**31, 2**32 - 1, 2**32, 2**63, 2**64 - 1, 2**64, 0.5]
# Spellings `json.dumps` cannot write: it prints -0 as 0 and 1e400 as
# Infinity. Each is spliced into the message text in place of a marker.
RAW_NUMBERS = ["-0", "-0.0", "1e400", "-1e400", "1E2", "1.0", "Infinity", "NaN"]
RAW_MARKER = "@@raw-number@@"


class Raw:
    """JSON text put into a message as it stands."""

    def __init__(self, text):
        self.text = text


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
    for text in RAW_NUMBERS:
        yield f"raw_{text}", Raw(text)
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


def lines(name):
    """One JSON value per line feed: a message may hold U+2028 or U+0085,
    which `splitlines` would break on."""
    text = (oracle / f"{name}.jsonl").read_text(encoding="utf-8")
    return [json.loads(line) for line in text.split(chr(10)) if line]


bases = []
for name in ["cases", "corpus"]:
    accepted = {answer["id"] for answer in lines(f"expected-{name}") if answer["ok"]}
    for case in lines(name):
        # A change to a message Rust already refuses shows nothing: the
        # refusal it had hides the one the change would cause.
        if case["kind"] not in ("command", "event") or case["id"] not in accepted:
            continue
        bases.append((len(case["json"]), case["kind"], json.loads(case["json"])))
if not bases:
    raise SystemExit("Rust accepted no message of the oracle: nothing to change")
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
            if isinstance(new, Raw):
                text = json.dumps(replaced(message, path, RAW_MARKER)).replace(json.dumps(RAW_MARKER), new.text)
            else:
                text = json.dumps(replaced(message, path, new))
            cases.append({"id": f"{kind}:{shape(path) or '.'}:{label}", "kind": kind, "json": text})



def depth(value):
    """Containers open at the deepest place of a message."""
    if isinstance(value, dict):
        return 1 + max((depth(inner) for inner in value.values()), default=0)
    if isinstance(value, list):
        return 1 + max((depth(inner) for inner in value), default=0)
    return 0


def nesting_probes():
    """serde_json stops at a fixed depth of known containers. A surface
    whose groups hold groups reaches every depth around that bound: each
    group adds three containers, and the innermost child sets the rest."""
    surfaces = [
        message for _, kind, message in bases
        if kind == "command" and isinstance(message, dict) and "ReplaceSurface" in message
    ]
    groups = [
        node for message in surfaces for node in message["ReplaceSurface"]["surface"]["nodes"]
        if isinstance(node, dict) and "Group" in node
    ]
    if not surfaces or not groups:
        raise SystemExit("the corpus has no surface with a group: no nesting probe can be built")
    surface = min(surfaces, key=lambda message: len(json.dumps(message)))
    group = min(groups, key=lambda node: len(json.dumps(node)))
    leaves = {}
    for message in surfaces:
        for node in message["ReplaceSurface"]["surface"]["nodes"]:
            leaves.setdefault(depth(node) % 3, node)
    wanted = set(range(120, 136))
    for leaf in leaves.values():
        for groups_deep in range(30, 46):
            node = leaf
            for _ in range(groups_deep):
                node = {"Group": {**group["Group"], "children": [node]}}
            message = {"ReplaceSurface": {"surface": {**surface["ReplaceSurface"]["surface"], "nodes": [node]}}}
            reached = depth(message)
            if reached in wanted:
                wanted.discard(reached)
                yield {"id": f"command:ReplaceSurface:nested_{reached}", "kind": "command", "json": json.dumps(message)}


cases.extend(nesting_probes())
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
