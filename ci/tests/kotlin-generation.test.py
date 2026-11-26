#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""The Kotlin contract is typed, schema-driven and refuses silent drift."""

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/generate-kotlin.py"
SCHEMA = ROOT / "schema/vauchi-contract-v1.json"


class KotlinGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.folder = Path(self.temporary.name)
        self.output = self.folder / "generated"
        self.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))

    def tearDown(self):
        self.temporary.cleanup()

    def generate(self, *arguments, env=None):
        path = self.folder / "schema.json"
        path.write_text(json.dumps(self.schema), encoding="utf-8")
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--schema", str(path), "--output", str(self.output), *arguments],
            capture_output=True,
            text=True,
            check=False,
            timeout=120,
            env=env,
        )

    def write(self):
        result = self.generate("--write")
        self.assertEqual(0, result.returncode, result.stderr)

    def variant(self, root, name):
        return next(
            variant["properties"][name]
            for variant in self.schema[root]["oneOf"]
            if name in variant.get("properties", {})
        )

    def assert_api(self, source, pattern):
        self.assertIsNotNone(re.search(pattern, source), f"missing typed Kotlin API: {pattern}")

    def test_every_wire_variant_has_a_typed_kotlin_case(self):
        self.write()

        source = "\n".join(path.read_text(encoding="utf-8") for path in self.output.glob("*.kt"))
        for root, type_name in [("command", "Command"), ("event", "Event")]:
            self.assert_api(source, rf"sealed\s+interface\s+{type_name}\b")
            for variant in self.schema[root]["oneOf"]:
                names = variant.get("enum", list(variant.get("properties", {})))
                for name in names:
                    with self.subTest(type=type_name, variant=name):
                        self.assert_api(source, rf"\b(?:data\s+class|data\s+object)\s+{re.escape(name)}\b")
        # Bytes, deadlines and revisions keep Rust's unsigned ranges in the public
        # API; a JsonObject or signed Long would erase that contract.
        self.assert_api(source, r"\bval\s+`?data`?\s*:\s*kotlin\.collections\.List<kotlin\.UByte>")
        self.assert_api(source, r"\bval\s+`?earliestSecs`?\s*:\s*kotlin\.UInt")
        self.assert_api(source, r"\bval\s+`?revision`?\s*:\s*kotlin\.ULong")

    def test_an_unknown_schema_restriction_stops_instead_of_being_ignored(self):
        self.variant("event", "HardwareError")["properties"]["transport"]["pattern"] = "^[A-Z]+$"

        result = self.generate("--write")

        self.assertEqual(2, result.returncode, result.stdout)
        self.assertIn("Event.HardwareError.transport", result.stderr)
        self.assertIn("unsupported", result.stderr)
        self.assertFalse(self.output.exists())

    def test_definitions_that_disagree_between_roots_are_rejected(self):
        self.schema["event"]["definitions"]["BleLinkDirection"] = {"type": "string", "enum": ["Sideways"]}

        result = self.generate("--write")

        self.assertEqual(2, result.returncode, result.stdout)
        self.assertIn("definition BleLinkDirection differs", result.stderr)
        self.assertFalse(self.output.exists())

    def test_check_detects_modified_generated_code_without_overwriting_it(self):
        self.write()
        path = next(self.output.glob("*.kt"))
        edited = path.read_text(encoding="utf-8") + "\n// local edit\n"
        path.write_text(edited, encoding="utf-8")

        result = self.generate()

        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn(path.name, result.stderr)
        self.assertEqual(edited, path.read_text(encoding="utf-8"))

    def test_a_failing_formatter_backend_cannot_report_current_generation(self):
        environment = dict(os.environ, JAVA_HOME=str(self.folder / "missing-jdk"))

        result = self.generate("--write", env=environment)

        self.assertEqual(2, result.returncode)
        self.assertIn("Kotlin formatting failed", result.stderr)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
