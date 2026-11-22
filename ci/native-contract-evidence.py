#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Write and check one generated product's lines of native-products.md.

A job calls this after its compile, semantic and fixture-replay steps have
passed, so the lines exist only for a revision and pipeline that ran them.
"""

import argparse
import os
from pathlib import Path

PRODUCTS = ("swift", "kotlin", "csharp")
REQUIRED = ("compile", "semantics", "fixture-replay")


def expected_lines(revision, pipeline, product):
    lines = [f"revision: {revision}", f"pipeline: {pipeline}"]
    lines.extend(f"{product} {check}: passed" for check in REQUIRED)
    return lines


def write_evidence(path, revision, pipeline, product):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(expected_lines(revision, pipeline, product)) + "\n", encoding="utf-8")


def validate_evidence(path, revision, pipeline, product):
    found = path.read_text(encoding="utf-8").splitlines()
    missing = [line for line in expected_lines(revision, pipeline, product) if line not in found]
    if missing:
        raise ValueError(f"incomplete evidence: {missing}")
    if any(f"{product} {check}: failed" in found for check in REQUIRED):
        raise ValueError("evidence records a failure")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--product", choices=PRODUCTS, required=True)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args()
    revision = os.environ.get("CI_COMMIT_SHA", "local")
    pipeline = os.environ.get("CI_PIPELINE_ID", "local")
    if args.write:
        write_evidence(args.path, revision, pipeline, args.product)
    if args.validate:
        validate_evidence(args.path, revision, pipeline, args.product)


if __name__ == "__main__":
    main()
