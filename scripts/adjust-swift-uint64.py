#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
schema = json.loads((root / "schema/vauchi-contract-v1.json").read_text())
names = set()


def collect(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties":
                for property_name, property_schema in value.items():
                    if property_schema.get("format") == "uint64":
                        names.add(property_name)
                    collect(property_schema)
            else:
                collect(value)
    elif isinstance(node, list):
        for item in node:
            collect(item)


collect(schema)
for generated in [root / "Sources/CommandContract/Command.swift", root / "Sources/EventContract/Event.swift"]:
    text = generated.read_text()
    for name in sorted(names):
        camel = re.sub(r"_([a-z])", lambda match: match.group(1).upper(), name)
        text = re.sub(rf"\b{camel}: Int\?", f"{camel}: UInt64?", text)
        text = re.sub(rf"\b{camel}: Int\b", f"{camel}: UInt64", text)
    generated.write_text(text)
print(f"mapped {len(names)} uint64 properties to UInt64")
