#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cases = []


def add(name, kind, value, raw=False):
    cases.append({
        "id": name,
        "kind": kind,
        "json": value if raw else json.dumps(value, ensure_ascii=False),
    })


for name, value in [
    ("unit", "AudioStop"),
    ("object", {"QrDisplay": {"data": "hello"}}),
    ("empty", {}),
    ("unknown", {"FutureCommand": {}}),
    ("multiple", {"QrDisplay": {"data": "hello"}, "BleConnect": {"device_id": "peer"}}),
    ("extra_field", {"QrDisplay": {"data": "hello", "extra": True}}),
    ("wrong_type", {"QrDisplay": {"data": 42}}),
    ("missing_payload", {"QrDisplay": {}}),
]:
    add(f"command_{name}", "command", value)
for name, value in [
    ("zero", 0),
    ("max", 4294967295),
    ("overflow", 4294967296),
    ("negative", -1),
    ("fraction", 1.5),
]:
    add("u32_" + name, "command", {"ScheduleWakeup": {
        "earliest_secs": value,
        "deadline_secs": 1,
        "min_interval_secs": 1,
        "delay_millis": 1,
    }})
add("duplicate_field", "command", '{"QrDisplay":{"data":"first","data":"last"}}', True)
add("escaped_duplicate_field", "command", '{"QrDisplay":{"data":"first","\\u0064ata":"last"}}', True)
add("duplicate_tag", "command", '{"QrDisplay":{"data":"first"},"QrDisplay":{"data":"last"}}', True)
for name, value in [
    ("ascii", "name"),
    ("empty", ""),
    ("control", "x\ny"),
    ("unicode_64", "é" * 64),
    ("unicode_65", "é" * 65),
]:
    add(f"ble_id_{name}", "event", {"BleAdvertisementObserved": {
        "id": value,
        "rssi": -40,
        "service_uuids": [],
    }})
for name, array in [("exact", [1, 2]), ("short", [1]), ("long", [1, 2, 3]), ("overflow", [1, 256])]:
    add(f"uuid_bytes_{name}", "event", {"BleAdvertisementObserved": {
        "id": "peer",
        "rssi": -40,
        "service_uuids": [{"Uuid16": array}],
    }})
for kind in ["event", "boundary"]:
    add(f"{kind}_capability_defaults", kind, {"HardwareCapabilitiesReported": {"capabilities": {}}})
    add(f"{kind}_capability_null_bool", kind, {"HardwareCapabilitiesReported": {
        "capabilities": {"has_camera": None},
    }})
    for name, value in [
        ("empty", ""),
        ("ascii_4096", "x" * 4096),
        ("ascii_4097", "x" * 4097),
        ("unicode_2049", "é" * 2049),
    ]:
        add(f"{kind}_text_{name}", kind, {"ValueChanged": {
            "surface_id": "s",
            "binding_id": "b",
            "value": {"text": value},
        }})
    add(f"{kind}_choice_null", kind, {"ValueChanged": {
        "surface_id": "s",
        "binding_id": "b",
        "value": {"choice": None},
    }})
    add(f"{kind}_choice_missing", kind, {"ValueChanged": {
        "surface_id": "s",
        "binding_id": "b",
        "value": {},
    }})
fixture = json.loads((root / "fixtures/presentation_contract_v1.json").read_text(encoding="utf-8"))
surface = next(
    command["ReplaceSurface"]["surface"]
    for command in fixture["initial_commands"]
    if "ReplaceSurface" in command
)
for name, value in [
    ("above_2_53", 9007199254740993),
    ("max", 18446744073709551615),
    ("overflow", 18446744073709551616),
]:
    changed = dict(surface, revision=value)
    add(f"u64_{name}", "command", {"ReplaceSurface": {"surface": changed}})
for index, command in enumerate(fixture["initial_commands"]):
    add(f"fixture_initial_{index}", "command", command)
for index, step in enumerate(fixture["steps"]):
    add(f"fixture_event_{index}", "event", step["event"])
    for command_index, command in enumerate(step["commands"]):
        add(f"fixture_step_{index}_{command_index}", "command", command)
output = root / "cache/oracle/cases.jsonl"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(
    "".join(json.dumps(case, ensure_ascii=False) + "\n" for case in cases),
    encoding="utf-8",
    newline="\n",
)
print(f"{len(cases)} cases written")
