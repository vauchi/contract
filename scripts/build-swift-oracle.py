#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
oracle = root / "cache/oracle"
oracle.mkdir(parents=True, exist_ok=True)


def generate(name):
    subprocess.run([sys.executable, f"scripts/swift-oracle-{name}.py"], cwd=root, check=True)


def ask_rust(name):
    with open(oracle / f"{name}.jsonl", "rb") as source, open(
        oracle / f"expected-{name}.jsonl", "wb"
    ) as expected:
        subprocess.run(
            [str(root / "target/debug/swift-oracle")],
            stdin=source,
            stdout=expected,
            check=True,
        )


for name in ["cases", "corpus"]:
    generate(name)
subprocess.run(["cargo", "build", "--bin", "swift-oracle", "--quiet"], cwd=root, check=True)
for name in ["cases", "corpus"]:
    ask_rust(name)
# The changed messages start from the ones Rust accepts, so they are made
# after its answers are in: a change to a message that was already refused
# shows nothing.
generate("mutants")
ask_rust("mutants")
print("Rust oracle inputs and expected results generated")
