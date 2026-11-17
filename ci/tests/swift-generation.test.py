#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SwiftGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name) / "contract"
        for directory in ["scripts", "schema", "Sources/CommandContract", "Sources/EventContract"]:
            (self.repo / directory).mkdir(parents=True, exist_ok=True)
        for name in ["check-swift-generation.sh", "adjust-swift-uint64.py"]:
            shutil.copy(ROOT / "scripts" / name, self.repo / "scripts" / name)
        (self.repo / "schema/vauchi-contract-v1.json").write_text(
            '{"command": {}, "event": {}}\n', encoding="utf-8"
        )
        for name in ["Command", "Event"]:
            (self.repo / f"Sources/{name}Contract/{name}.swift").write_text(
                "generated\n", encoding="utf-8"
            )
        self.bin = Path(self.temporary.name) / "bin"
        self.bin.mkdir()
        npx = self.bin / "npx"
        npx.write_text(
            "#!/bin/sh\n"
            "while [ \"$#\" -gt 0 ]; do\n"
            "  if [ \"$1\" = -o ]; then output=$2; shift 2; else shift; fi\n"
            "done\n"
            "printf 'generated\\n' > \"$output\"\n",
            encoding="utf-8",
        )
        npx.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    def run_check(self):
        environment = dict(os.environ)
        environment["PATH"] = f"{self.bin}:{environment['PATH']}"
        return subprocess.run(
            ["bash", str(self.repo / "scripts/check-swift-generation.sh")],
            cwd=self.repo,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_generated_files_match(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_drift_fails_without_overwriting_the_source(self):
        source = self.repo / "Sources/CommandContract/Command.swift"
        source.write_text("drift\n", encoding="utf-8")
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(source.read_text(encoding="utf-8"), "drift\n")

    def test_json_any_top_level_is_rejected(self):
        npx = self.bin / "npx"
        script = npx.read_text(encoding="utf-8").replace(
            "generated", "public typealias Command = JSONAny"
        )
        npx.write_text(script, encoding="utf-8")
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
