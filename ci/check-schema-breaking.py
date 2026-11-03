#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Fail when the schema breaks a shell built against the previous release.

ADR-078 item 8: contract minors are additive. Compared with the last
released schema, the new one may add properties, variants and types; it may
not remove a property or a variant, change a property's type, make an
optional property required, or tighten a bound (a lower maximum, a higher
minimum, a shorter maxLength or maxItems, a longer minLength or minItems).

    check-schema-breaking.py OLD.json NEW.json

Exit 0 when NEW is backward compatible with OLD, 1 with one line per break.
"""
from __future__ import annotations

import json
import sys
from typing import Any

UPPER = ("maximum", "exclusiveMaximum", "maxLength", "maxItems", "maxProperties")
LOWER = ("minimum", "exclusiveMinimum", "minLength", "minItems", "minProperties")


def _type_of(node: dict[str, Any]) -> Any:
    t = node.get("type")
    return sorted(t) if isinstance(t, list) else t


def _variants(node: dict[str, Any]) -> dict[str, dict[str, Any]] | None:
    """A oneOf/anyOf list keyed by a stable name: the enum value, the required
    tag, or the single property name; None when the node is not a union."""
    arms = node.get("oneOf") or node.get("anyOf")
    if not isinstance(arms, list):
        return None
    out: dict[str, dict[str, Any]] = {}
    for i, arm in enumerate(arms):
        key: str
        if isinstance(arm, dict) and isinstance(arm.get("enum"), list) and arm["enum"]:
            key = f"enum:{arm['enum'][0]}"
        elif isinstance(arm, dict) and isinstance(arm.get("properties"), dict) and len(arm["properties"]) == 1:
            key = f"prop:{next(iter(arm['properties']))}"
        elif isinstance(arm, dict) and isinstance(arm.get("required"), list) and arm["required"]:
            key = f"required:{','.join(sorted(arm['required']))}"
        elif isinstance(arm, dict) and "$ref" in arm:
            key = f"ref:{arm['$ref']}"
        else:
            key = f"arm:{i}"
        out[key] = arm if isinstance(arm, dict) else {}
    return out


def compare(old: Any, new: Any, path: str, breaks: list[str]) -> None:
    if old == new or old is False or new is True:
        return
    if new is False or (old is True and new != {}):
        breaks.append(f"{path}: schema became more restrictive")
        return
    if old is True:
        old = {}
    if not isinstance(old, dict) or not isinstance(new, dict):
        return
    if "$ref" in old and old.get("$ref") != new.get("$ref"):
        breaks.append(f"{path}: reference changed from {old['$ref']} to {new.get('$ref')}")
        return
    old_type, new_type = _type_of(old), _type_of(new)
    if old_type is not None and new_type is not None and old_type != new_type:
        breaks.append(f"{path}: type changed from {old_type} to {new_type}")
    if isinstance(old.get("enum"), list) and isinstance(new.get("enum"), list):
        for value in old["enum"]:
            if value not in new["enum"]:
                breaks.append(f"{path}: enum value {value!r} removed")
    old_props, new_props = old.get("properties") or {}, new.get("properties") or {}
    for name, sub in old_props.items():
        if name not in new_props:
            breaks.append(f"{path}.{name}: property removed")
        else:
            compare(sub, new_props[name], f"{path}.{name}", breaks)
    for name in set(new.get("required") or []) - set(old.get("required") or []):
        breaks.append(f"{path}.{name}: property became required")
    for key in UPPER:
        if key in old and key in new and new[key] < old[key]:
            breaks.append(f"{path}: {key} tightened from {old[key]} to {new[key]}")
        if key in new and key not in old:
            breaks.append(f"{path}: {key} {new[key]} added where none was")
    for key in LOWER:
        if key in new and key not in old:
            breaks.append(f"{path}: {key} {new[key]} added where none was")
        if key in old and key in new and new[key] > old[key]:
            breaks.append(f"{path}: {key} tightened from {old[key]} to {new[key]}")
    if "items" in old and "items" in new:
        compare(old["items"], new["items"], f"{path}[]", breaks)
    compare(old.get("additionalProperties", True), new.get("additionalProperties", True),
            f"{path}.*", breaks)
    ov, nv = _variants(old), _variants(new)
    if ov is not None and nv is not None:
        for key, arm in ov.items():
            if key not in nv:
                breaks.append(f"{path}: variant {key} removed")
            else:
                compare(arm, nv[key], f"{path}<{key}>", breaks)
    for defs_key in ("definitions", "$defs"):
        old_definitions, new_definitions = old.get(defs_key) or {}, new.get(defs_key) or {}
        for name, sub in old_definitions.items():
            if name not in new_definitions:
                breaks.append(f"{path}.{defs_key}.{name}: type removed")
            else:
                compare(sub, new_definitions[name], f"{path}.{defs_key}.{name}", breaks)


def breaking_changes(old: dict[str, Any], new: dict[str, Any]) -> list[str]:
    breaks: list[str] = []
    if old.get("schema_version") != new.get("schema_version"):
        breaks.append(f"schema_version changed from {old.get('schema_version')} to {new.get('schema_version')}")
    for root in ("command", "event"):
        if root in old and root not in new:
            breaks.append(f"{root}: root schema removed")
        elif root in old:
            compare(old[root], new.get(root, {}), root, breaks)
    return breaks


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    old = json.load(open(argv[0], encoding="utf-8"))
    new = json.load(open(argv[1], encoding="utf-8"))
    breaks = breaking_changes(old, new)
    for line in breaks:
        print(f"BREAKING: {line}")
    print(f"{len(breaks)} breaking change(s) against {argv[0]}")
    return 1 if breaks else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
