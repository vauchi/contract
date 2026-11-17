#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixtures = root / "fixtures"
cases = []


def add(name, kind, value):
    cases.append({"id": name, "kind": kind, "json": json.dumps(value)})


presentation = json.loads((fixtures / "presentation_contract_v1.json").read_text())
for group in ["initial_commands", "effect_commands"]:
    for index, command in enumerate(presentation[group]):
        add(f"{group}_{index}", "command", command)
for kind, group in [("command", "commands"), ("event", "events")]:
    for index, item in enumerate(presentation["file_picker_contract"][group]):
        add(f"file_picker_{kind}_{index}", kind, item)
for index, step in enumerate(presentation["steps"]):
    add(f"step_event_{index}", "event", step["event"])
    for command_index, command in enumerate(step["commands"]):
        add(f"step_command_{index}_{command_index}", "command", command)
catalog = json.loads((fixtures / "screen_catalog_v1.json").read_text())
for index, screen in enumerate(catalog["screens"]):
    for command_index, command in enumerate(screen["commands"]):
        add(f"catalog_{index}_{command_index}", "command", command)
output = root / "cache/oracle/corpus.jsonl"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("".join(json.dumps(case) + "\n" for case in cases))
print(f"{len(cases)} corpus messages")
