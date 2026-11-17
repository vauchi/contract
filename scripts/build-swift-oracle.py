#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
oracle = root / "cache/oracle"
oracle.mkdir(parents=True, exist_ok=True)
experiments = root.parent / "_private/docs/problems/2026-11-05-generated-swift-contract/experiments"
for name in ("cases", "corpus"):
    source = (experiments / f"{name}.py").read_text()
    (root / "cache" / f"{name}.py").write_text(source.replace("/private/tmp/vauchi-1082-oracle", "cache/oracle"))
    subprocess.run(["python3", f"cache/{name}.py"], cwd=root, check=True, env={**os.environ, "VAUCHI_WORKSPACE": str(root.parent)})
subprocess.run([
    "cargo", "build", "--manifest-path", str(experiments / "Cargo.toml"),
    "--target-dir", "cache/oracle/target", "--quiet"
], cwd=root, check=True)
for name in ("cases", "corpus"):
    with open(oracle / f"{name}.jsonl", "rb") as source, open(oracle / f"expected-{name}.jsonl", "wb") as expected:
        subprocess.run([str(oracle / "target/debug/vauchi-contract-oracle")], stdin=source, stdout=expected, check=True)
print("Rust oracle inputs and expected results generated")
