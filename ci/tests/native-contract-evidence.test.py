#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "native-contract-evidence.py"
spec = importlib.util.spec_from_file_location("swift_evidence", SCRIPT)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class SwiftContractEvidenceTests(unittest.TestCase):
    def test_write_and_validate_complete_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "native-products.md"
            evidence.write_evidence(path, "abc123", "42")
            evidence.validate_evidence(path, "abc123", "42")

    def test_stale_revision_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "native-products.md"
            evidence.write_evidence(path, "abc123", "42")
            with self.assertRaisesRegex(ValueError, "incomplete evidence"):
                evidence.validate_evidence(path, "def456", "42")

    def test_wrong_pipeline_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "native-products.md"
            evidence.write_evidence(path, "abc123", "42")
            with self.assertRaisesRegex(ValueError, "incomplete evidence"):
                evidence.validate_evidence(path, "abc123", "99")

    def test_partial_evidence_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "native-products.md"
            evidence.write_evidence(path, "abc123", "42")
            path.write_text("revision: abc123\npipeline: 42\nswift compile: passed\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "incomplete evidence"):
                evidence.validate_evidence(path, "abc123", "42")

    def test_failure_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "native-products.md"
            evidence.write_evidence(path, "abc123", "42")
            path.write_text("revision: abc123\npipeline: 42\nswift compile: failed\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "incomplete evidence|records a failure"):
                evidence.validate_evidence(path, "abc123", "42")


if __name__ == "__main__":
    unittest.main()
