#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "native-contract-evidence.py"
spec = importlib.util.spec_from_file_location("native_evidence", SCRIPT)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class NativeContractEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "native-products.md"

    def tearDown(self):
        self.temporary.cleanup()

    def test_write_and_validate_complete_evidence(self):
        for product in evidence.PRODUCTS:
            with self.subTest(product=product):
                evidence.write_evidence(self.path, "abc123", "42", product)

                evidence.validate_evidence(self.path, "abc123", "42", product)
                self.assertEqual(
                    [
                        "revision: abc123",
                        "pipeline: 42",
                        f"{product} compile: passed",
                        f"{product} semantics: passed",
                        f"{product} fixture-replay: passed",
                    ],
                    self.path.read_text(encoding="utf-8").splitlines(),
                )

    def test_stale_revision_is_rejected(self):
        evidence.write_evidence(self.path, "abc123", "42", "swift")

        with self.assertRaisesRegex(ValueError, "incomplete evidence"):
            evidence.validate_evidence(self.path, "def456", "42", "swift")

    def test_wrong_pipeline_is_rejected(self):
        evidence.write_evidence(self.path, "abc123", "42", "swift")

        with self.assertRaisesRegex(ValueError, "incomplete evidence"):
            evidence.validate_evidence(self.path, "abc123", "99", "swift")

    def test_partial_evidence_is_rejected(self):
        self.path.write_text("revision: abc123\npipeline: 42\nswift compile: passed\n", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "incomplete evidence"):
            evidence.validate_evidence(self.path, "abc123", "42", "swift")

    def test_another_products_evidence_is_rejected(self):
        evidence.write_evidence(self.path, "abc123", "42", "swift")

        with self.assertRaisesRegex(ValueError, "incomplete evidence"):
            evidence.validate_evidence(self.path, "abc123", "42", "csharp")

    def test_a_recorded_failure_is_rejected_beside_complete_passes(self):
        for product in evidence.PRODUCTS:
            with self.subTest(product=product):
                evidence.write_evidence(self.path, "abc123", "42", product)
                with self.path.open("a", encoding="utf-8") as text:
                    text.write(f"{product} semantics: failed\n")

                with self.assertRaisesRegex(ValueError, "records a failure"):
                    evidence.validate_evidence(self.path, "abc123", "42", product)

    def test_the_command_line_names_its_product(self):
        written = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.path), "--product", "csharp", "--write", "--validate"],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

        self.assertEqual(0, written.returncode, written.stderr)
        self.assertIn("csharp fixture-replay: passed", self.path.read_text(encoding="utf-8").splitlines())

    def test_the_command_line_refuses_an_unknown_product(self):
        refused = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.path), "--product", "cobol", "--write"],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

        self.assertEqual(2, refused.returncode, refused.stdout)
        self.assertFalse(self.path.exists())

    def test_the_command_line_fails_on_evidence_it_cannot_validate(self):
        evidence.write_evidence(self.path, "abc123", "42", "swift")

        refused = subprocess.run(
            [sys.executable, str(SCRIPT), str(self.path), "--product", "csharp", "--validate"],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

        self.assertNotEqual(0, refused.returncode, refused.stdout)


if __name__ == "__main__":
    unittest.main()
