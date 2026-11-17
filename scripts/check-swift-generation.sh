#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/schema" "$scratch/Sources/CommandContract" "$scratch/Sources/EventContract"
cp "$repo/schema/vauchi-contract-v1.json" "$scratch/schema/vauchi-contract-v1.json"
python3 - "$repo/schema/vauchi-contract-v1.json" "$scratch" <<'PY'
import json
import sys
from pathlib import Path

schema = json.loads(Path(sys.argv[1]).read_text())
for root in ["command", "event"]:
    Path(sys.argv[2], f"{root}.json").write_text(json.dumps(schema[root]))
PY
npx --yes --package quicktype@26.0.0 quicktype -s schema -l swift \
  --access-level public --top-level Command "$scratch/command.json" \
  -o "$scratch/Sources/CommandContract/Command.swift"
npx --yes --package quicktype@26.0.0 quicktype -s schema -l swift \
  --access-level public --top-level Event "$scratch/event.json" \
  -o "$scratch/Sources/EventContract/Event.swift"
python3 "$repo/scripts/adjust-swift-uint64.py" "$scratch"
if grep -Eq 'public typealias (Command|Event) = JSONAny' \
    "$scratch/Sources/CommandContract/Command.swift" \
    "$scratch/Sources/EventContract/Event.swift"; then
    printf 'Swift generation collapsed a contract root to JSONAny\n' >&2
    exit 1
fi
if [ "${1:-}" = "--write" ]; then
    cp "$scratch/Sources/CommandContract/Command.swift" "$repo/Sources/CommandContract/Command.swift"
    cp "$scratch/Sources/EventContract/Event.swift" "$repo/Sources/EventContract/Event.swift"
fi
cmp "$scratch/Sources/CommandContract/Command.swift" "$repo/Sources/CommandContract/Command.swift"
cmp "$scratch/Sources/EventContract/Event.swift" "$repo/Sources/EventContract/Event.swift"
printf 'Swift generation is deterministic\n'
