# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "fetch-screen-catalog.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("catalog", SCRIPT)
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)
REVISION = "a" * 40
CORE_REVISION = "b" * 40
RAW = json.dumps({"schema_version": 1, "screens": [
    {"code_id": "home", "commands": [{"ClearSurface": None}]}]}).encode()


class CatalogEvidenceTest(unittest.TestCase):
    def test_native_collection_without_stdlib_tomllib(self):
        with patch.dict(sys.modules, {"tomllib": None}):
            legacy = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(legacy)
            (self.root / "core-ref").write_text("v0.97.0\n")
            raw, evidence = legacy.collect(self.root, self.fetch)
        self.assertEqual(RAW, raw)
        self.assertEqual("v0.96.2", evidence["contract_ref"])
        self.assertEqual(REVISION, evidence["contract_revision"])

    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        self.calls = []

    def fetch(self, project, filename, ref):
        self.calls.append((project, filename, ref))
        if project == "core":
            self.assertEqual("v0.97.0", ref)
            return (b'[workspace.dependencies]\nvauchi-contract = { git = "https://gitlab.com/vauchi/contract.git", tag = "v0.96.2" }', CORE_REVISION)
        self.assertEqual("contract", project)
        self.assertIn(ref, ("v0.96.2", REVISION))
        if filename == "fixtures/screen_catalog_inventory_v1.json":
            self.assertEqual(REVISION, ref)
            return b'{"schema_version":1,"screen_ids":["home"]}', REVISION
        self.assertEqual("fixtures/screen_catalog_v1.json", filename)
        return RAW, REVISION

    def test_native_pins_resolve_to_the_consumed_contract(self):
        fixtures = {
            "project.yml": 'packages:\n  VauchiPlatform:\n    url: https://gitlab.com/vauchi/vauchi-platform-swift.git\n    version: "0.97.0"\n',
            "core-ref": "# Core release\nv0.97.0\n",
            "app/build.gradle.kts": 'implementation("app.vauchi:vauchi-platform:0.97.0")\n',
        }
        for name, content in fixtures.items():
            with self.subTest(name=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
                raw, evidence = catalog.collect(self.root, self.fetch)
                self.assertEqual(RAW, raw)
                self.assertEqual(REVISION, evidence["contract_revision"])
                self.assertEqual("v0.96.2", evidence["contract_ref"])
                self.assertEqual(hashlib.sha256(RAW).hexdigest(), evidence["sha256"])
                self.assertEqual(1, evidence["screens"])
                path.unlink()

    def test_rust_lock_uses_exact_contract_commit(self):
        (self.root / "Cargo.lock").write_text(
            'version = 4\n[[package]]\nname = "vauchi-contract"\nversion = "0.96.2"\n'
            f'source = "git+https://gitlab.com/vauchi/contract.git?tag=v0.96.2#{REVISION}"\n')
        _, evidence = catalog.collect(self.root, self.fetch)
        self.assertEqual(REVISION, evidence["contract_ref"])
        self.assertEqual([("contract", "fixtures/screen_catalog_v1.json", REVISION),
                          ("contract", "fixtures/screen_catalog_inventory_v1.json", REVISION)], self.calls)

    def test_missing_pin_and_floating_native_version_fail(self):
        with self.assertRaises(catalog.CatalogError):
            catalog.collect(self.root, self.fetch)
        (self.root / "core-ref").write_text("main\n")
        with self.assertRaises(catalog.CatalogError):
            catalog.collect(self.root, self.fetch)
        self.assertEqual([], self.calls)

    def test_unavailable_catalog_has_no_fallback(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        def unavailable(project, filename, ref):
            if project == "contract":
                raise catalog.CatalogError("unavailable")
            return self.fetch(project, filename, ref)
        with self.assertRaisesRegex(catalog.CatalogError, "unavailable"):
            catalog.collect(self.root, unavailable)

    def test_invalid_full_catalog_is_rejected(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        for payload in (b"{", b"null", b"{}", b'{"schema_version":1,"screens":[]}',
                        b'{"initial_commands":[],"steps":[]}',
                        b'{"schema_version":1,"screens":[{"code_id":"home"}]}'):
            with self.subTest(payload=payload):
                def invalid(project, filename, ref):
                    return ((payload, REVISION) if project == "contract"
                            else self.fetch(project, filename, ref))
                with self.assertRaises(catalog.CatalogError):
                    catalog.collect(self.root, invalid)

    def test_inventory_removal_mutations_and_extra_ids_fail(self):
        inventory_path = SCRIPT.parents[1] / "fixtures/screen_catalog_inventory_v1.json"
        raw = inventory_path.read_bytes()
        ids = json.loads(raw)["screen_ids"]
        catalog.validate_inventory(raw, set(ids))
        for removed in ids:
            with self.subTest(removed=removed):
                with self.assertRaisesRegex(catalog.CatalogError, "inventory mismatch"):
                    catalog.validate_inventory(raw, set(ids) - {removed})
        with self.assertRaisesRegex(catalog.CatalogError, "inventory mismatch"):
            catalog.validate_inventory(raw, set(ids) | {"unexpected-screen"})

    def test_committed_catalog_matches_independent_inventory(self):
        fixtures = SCRIPT.parents[1] / "fixtures"
        screens = json.loads((fixtures / "screen_catalog_v1.json").read_bytes())["screens"]
        ids = {screen["code_id"] for screen in screens}
        self.assertEqual(len(screens), len(ids))
        catalog.validate_inventory((fixtures / "screen_catalog_inventory_v1.json").read_bytes(), ids)

    def test_malformed_inventory_is_rejected(self):
        for payload in (b"{", b"null", b"{}", b'{"schema_version":true,"screen_ids":["home"]}',
                        b'{"schema_version":1,"screen_ids":[]}',
                        b'{"schema_version":1,"screen_ids":["home","home"]}',
                        b'{"schema_version":1,"screen_ids":[""]}',
                        b'{"schema_version":1,"screen_ids":[null]}'):
            with self.subTest(payload=payload):
                with self.assertRaises(catalog.CatalogError):
                    catalog.validate_inventory(payload, {"home"})

    def test_legacy_release_uses_its_frozen_inventory(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        raw = (SCRIPT.parents[1] / "fixtures/screen_catalog_v1.json").read_bytes()
        def legacy(project, filename, ref):
            if project == "core":
                return self.fetch(project, filename, ref)
            self.assertEqual("fixtures/screen_catalog_v1.json", filename)
            return raw, "1f6c1b971bef1edb6fffab21c0bbdaa6664729fa"
        _, evidence = catalog.collect(self.root, legacy)
        self.assertEqual("frozen:1f6c1b971bef1edb6fffab21c0bbdaa6664729fa",
                         evidence["inventory_source"])
        self.assertEqual(61, evidence["screens"])
        incomplete = json.loads(raw)
        incomplete["screens"].pop()
        raw = json.dumps(incomplete).encode()
        with self.assertRaisesRegex(catalog.CatalogError, "inventory mismatch"):
            catalog.collect(self.root, legacy)

    def test_missing_inventory_and_wrong_revision_fail_closed(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        for mismatch in (False, True):
            with self.subTest(mismatch=mismatch):
                def fetch(project, filename, ref):
                    if "inventory" in filename:
                        if mismatch:
                            return b'{"schema_version":1,"screen_ids":["home"]}', CORE_REVISION
                        raise catalog.CatalogError("inventory unavailable")
                    return self.fetch(project, filename, ref)
                with self.assertRaises(catalog.CatalogError):
                    catalog.collect(self.root, fetch)


if __name__ == "__main__":
    unittest.main()
