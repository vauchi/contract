#!/bin/sh

# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# ci/check-schema-breaking.py (ADR-078 item 8, contract:breaking): additive
# changes pass; a removed property or variant, a retyped field, a new
# required property and a tightened bound fail with a named reason. CC-27:
# every failing case below was observed red against the script.

set -eu

HERE=$(cd "$(dirname "$0")/../.." && pwd)
CHECK="$HERE/ci/check-schema-breaking.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cat > "$T/old.json" <<'EOF'
{
  "schema_version": 1,
  "command": {
    "oneOf": [
      {"type": "object", "required": ["ShowText"], "properties": {"ShowText": {"type": "object",
        "properties": {"text": {"type": "string", "maxLength": 200}, "tone": {"$ref": "#/definitions/Tone"}},
        "required": ["text"]}}},
      {"type": "string", "enum": ["Dismiss"]}
    ],
    "definitions": {"Tone": {"type": "string", "enum": ["neutral", "warning"]}}
  },
  "event": {"oneOf": [{"type": "string", "enum": ["Tapped"]}]}
}
EOF

# `python3 - "$T/old.json" "$T/new.json" <<EOF ... EOF` would be shorter,
# but BusyBox sh and bash disagree on heredoc quoting inside $(); a small
# helper that applies one JSON edit keeps every case to one line.
edit() {
    python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
exec(sys.argv[3])
json.dump(doc, open(sys.argv[2], "w"))' "$T/old.json" "$T/new.json" "$1"
}

expect_ok() {
    out=$(python3 "$CHECK" "$T/old.json" "$T/new.json" 2>&1) || fail "$1 must pass; got: $out"
}

expect_break() {
    out=$(python3 "$CHECK" "$T/old.json" "$T/new.json" 2>&1) && fail "$1 must fail; got: $out"
    printf '%s\n' "$out" | grep -q "BREAKING: $2" || fail "$1 must say '$2'; got: $out"
}

edit 'pass'
expect_ok "an identical schema"

edit 'doc["command"]["oneOf"][0]["properties"]["ShowText"]["properties"]["icon"] = {"type": "string"}'
expect_ok "an added optional property"

edit 'doc["command"]["oneOf"].append({"type": "string", "enum": ["Flash"]})'
expect_ok "an added variant"

edit 'doc["command"]["definitions"]["Tone"]["enum"].append("success")'
expect_ok "an added enum value"

edit 'doc["command"]["oneOf"][0]["properties"]["ShowText"]["properties"]["text"]["maxLength"] = 400'
expect_ok "a loosened bound"

edit 'del doc["command"]["oneOf"][0]["properties"]["ShowText"]["properties"]["tone"]'
expect_break "a removed property" "command<prop:ShowText>.ShowText.tone: property removed"

edit 'del doc["command"]["oneOf"][1]'
expect_break "a removed variant" "command: variant enum:Dismiss removed"

edit 'doc["command"]["oneOf"][0]["properties"]["ShowText"]["properties"]["text"]["type"] = "integer"'
expect_break "a retyped property" "command<prop:ShowText>.ShowText.text: type changed from string to integer"

edit 'doc["command"]["oneOf"][0]["properties"]["ShowText"]["required"].append("tone")'
expect_break "a new required property" "command<prop:ShowText>.ShowText.tone: property became required"

edit 'doc["command"]["oneOf"][0]["properties"]["ShowText"]["properties"]["text"]["maxLength"] = 100'
expect_break "a tightened bound" "command<prop:ShowText>.ShowText.text: maxLength tightened from 200 to 100"

edit 'del doc["command"]["definitions"]["Tone"]["enum"][1]'
expect_break "a removed enum value" "command.definitions.Tone: enum value 'warning' removed"

edit 'del doc["command"]["definitions"]["Tone"]'
expect_break "a removed type" "command.definitions.Tone: type removed"

edit 'doc["schema_version"] = 2'
expect_break "a new schema_version" "schema_version changed from 1 to 2"

# The real schema against itself is compatible, and large enough to matter.
python3 "$CHECK" "$HERE/schema/vauchi-contract-v1.json" "$HERE/schema/vauchi-contract-v1.json" >/dev/null \
    || fail "the committed schema must be compatible with itself"

echo "check-schema-breaking.test.sh: OK"
