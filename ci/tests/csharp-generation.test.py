#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""The C# generator stops instead of guessing, and its check can fail."""

import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/generate-csharp.py"
SCHEMA = ROOT / "schema/vauchi-contract-v1.json"

spec = importlib.util.spec_from_file_location("generate_csharp", SCRIPT)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CSharpGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.folder = Path(self.temporary.name)
        self.output = self.folder / "Generated"
        self.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))

    def tearDown(self):
        self.temporary.cleanup()

    def run_generator(self, *arguments, schema=None):
        schema_path = self.folder / "schema.json"
        schema_path.write_text(json.dumps(schema or self.schema), encoding="utf-8")
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--schema", str(schema_path), "--output", str(self.output), *arguments],
            capture_output=True,
            text=True,
            check=False,
            timeout=120,
        )

    def write(self):
        result = self.run_generator("--write")
        self.assertEqual(0, result.returncode, result.stderr)

    def event_variant(self, schema, name):
        return next(
            variant["properties"][name]
            for variant in schema["event"]["oneOf"]
            if name in variant.get("properties", {})
        )

    def test_the_committed_files_are_what_the_schema_generates(self):
        result = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True, check=False, timeout=120)

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("C# generation is current", result.stdout)

    def test_freshly_written_files_pass_the_check(self):
        self.write()

        result = self.run_generator()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["Command.g.cs", "Event.g.cs", "Types.g.cs"], sorted(path.name for path in self.output.iterdir()))

    def test_an_edited_file_fails_the_check_and_is_left_as_it_was(self):
        self.write()
        edited = self.output / "Event.g.cs"
        text = edited.read_text(encoding="utf-8") + "// edited by hand\n"
        edited.write_text(text, encoding="utf-8", newline="\n")

        result = self.run_generator()

        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("Event.g.cs", result.stderr)
        self.assertEqual(text, edited.read_text(encoding="utf-8"))

    def test_a_missing_file_fails_the_check(self):
        self.write()
        (self.output / "Command.g.cs").unlink()

        result = self.run_generator()

        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("Command.g.cs", result.stderr)

    def test_a_generated_file_the_schema_no_longer_produces_fails_the_check(self):
        self.write()
        (self.output / "Retired.g.cs").write_text("// left behind\n", encoding="utf-8")

        result = self.run_generator()

        self.assertEqual(1, result.returncode, result.stdout)
        self.assertIn("Retired.g.cs", result.stderr)

    def test_a_schema_keyword_the_generator_does_not_know_stops_it(self):
        self.event_variant(self.schema, "HardwareError")["properties"]["transport"]["pattern"] = "^[A-Z]+$"

        result = self.run_generator("--write")

        self.assertEqual(2, result.returncode, result.stdout)
        self.assertIn("Event.HardwareError.transport: unsupported keywords ['pattern']", result.stderr)
        self.assertFalse(self.output.exists())

    def test_a_rule_for_a_field_the_schema_no_longer_has_stops_it(self):
        activated = self.event_variant(self.schema, "ActionActivated")
        del activated["properties"]["surface_id"]
        activated["required"].remove("surface_id")

        result = self.run_generator("--write")

        self.assertEqual(2, result.returncode, result.stdout)
        self.assertIn("Event.ActionActivated.surface_id", result.stderr)

    def test_definitions_that_differ_between_the_roots_stop_it(self):
        self.schema["event"]["definitions"]["BleLinkDirection"] = {"enum": ["Sideways"], "type": "string"}

        result = self.run_generator("--write")

        self.assertEqual(2, result.returncode, result.stdout)
        self.assertIn("definition BleLinkDirection differs between the two roots", result.stderr)

    def test_every_rust_field_of_an_identifier_type_has_its_rule(self):
        """The schema shows a `SurfaceId` as a plain string, so the generator
        lists the fields. A field added in Rust and not listed would be read
        without the identifier rule."""
        declared = re.compile(r"\b\w+: [\w<, ]*\b(?:SurfaceId|InteractionId|BindingId)\b[\w>, ]*\s*[,}]")
        in_rust = sum(
            len(declared.findall(source.read_text(encoding="utf-8")))
            for source in sorted((ROOT / "src").rglob("*.rs"))
        )

        self.assertGreater(in_rust, 0)
        self.assertEqual(in_rust, len(generator.IDENTIFIERS))
        self.assertEqual(len(generator.IDENTIFIERS), len(set(generator.IDENTIFIERS)))


if __name__ == "__main__":
    unittest.main()
