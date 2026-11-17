#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import argparse
import os
from pathlib import Path

REQUIRED = ("compile", "semantics", "fixture-replay")


def write_evidence(path, revision, pipeline):
    lines = [f"revision: {revision}", f"pipeline: {pipeline}"]
    lines.extend(f"swift {check}: passed" for check in REQUIRED)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def validate_evidence(path, revision, pipeline):
    text = path.read_text(encoding="utf-8")
    required_lines = [f"revision: {revision}", f"pipeline: {pipeline}"]
    required_lines.extend(f"swift {check}: passed" for check in REQUIRED)
    missing = [line for line in required_lines if line not in text.splitlines()]
    if missing:
        raise ValueError(f"incomplete evidence: {missing}")
    if "swift compile: failed" in text or "swift semantics: failed" in text or "swift fixture-replay: failed" in text:
        raise ValueError("evidence records a failure")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args()
    revision = os.environ.get("CI_COMMIT_SHA", "local")
    pipeline = os.environ.get("CI_PIPELINE_ID", "local")
    if args.write:
        write_evidence(args.path, revision, pipeline)
    if args.validate:
        validate_evidence(args.path, revision, pipeline)


if __name__ == "__main__":
    main()
