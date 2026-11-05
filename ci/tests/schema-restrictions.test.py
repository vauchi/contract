# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Compatibility must reject newly imposed constraints through the CLI."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECK = Path(__file__).resolve().parents[1] / "check-schema-breaking.py"


class RestrictionsTest(unittest.TestCase):
    def test_added_variants_report_direction_without_claiming_receiver_compatibility(self):
        with tempfile.TemporaryDirectory() as folder:
            old, new = [Path(folder) / name for name in ("old.json", "new.json")]
            old.write_text(json.dumps({"schema_version": 1, "command": {
                "oneOf": [{"enum": ["Stop"]}],
            }}))
            new.write_text(json.dumps({"schema_version": 1, "command": {
                "oneOf": [{"enum": ["Stop", "Future"]}],
            }}))
            result = subprocess.run([sys.executable, str(CHECK), str(old), str(new)],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("0 breaking change(s)", result.stdout)
            self.assertIn("old-data structure", result.stdout)
            self.assertIn("old receivers", result.stdout)
            reverse = subprocess.run([sys.executable, str(CHECK), str(new), str(old)],
                                     capture_output=True, text=True, timeout=10)
            self.assertEqual(1, reverse.returncode, reverse.stdout + reverse.stderr)
            self.assertIn("Future", reverse.stdout)

    def compare(self, old, new, expected):
        with tempfile.TemporaryDirectory() as folder:
            paths = [Path(folder) / name for name in ("old.json", "new.json")]
            for path, node in zip(paths, (old, new)):
                path.write_text(json.dumps({"schema_version": 1, "command": node}))
            result = subprocess.run([sys.executable, str(CHECK), *map(str, paths)],
                                    capture_output=True, text=True, timeout=10)
        self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
        if expected:
            self.assertIn("BREAKING: command", result.stdout)
        else:
            self.assertIn("0 breaking change(s)", result.stdout)

    def test_added_bounds_and_their_removal(self):
        for kind, keys in (
            ("string", ("minLength", "maxLength")),
            ("array", ("minItems", "maxItems")),
            ("object", ("minProperties", "maxProperties")),
            ("number", ("minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum")),
        ):
            for key in keys:
                with self.subTest(key=key):
                    old, new = {"type": kind}, {"type": kind, key: 2}
                    self.compare(old, new, 1)
                    self.compare(new, old, 0)

    def test_additional_properties_restrictions(self):
        for old in ({"type": "object"}, {"type": "object", "additionalProperties": True}):
            for restriction in (False, {"type": "string"}):
                with self.subTest(old=old, restriction=restriction):
                    new = {"type": "object", "additionalProperties": restriction}
                    self.compare(old, new, 1)
                    self.compare(new, old, 0)

    def test_boolean_schemas(self):
        self.compare(True, False, 1)
        self.compare({}, False, 1)
        self.compare(False, True, 0)
        self.compare(True, True, 0)
        self.compare(False, False, 0)


if __name__ == "__main__":
    unittest.main()
