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
    def journey_artifacts(self):
        blobs = {
            "screen_catalog_v1.json": RAW,
            "screen_catalog_inventory_v1.json": b'{"schema_version":1,"screen_ids":["home"]}',
            "presentation_contract_v1.json": b'{"schema_version":1,"initial_commands":[],"steps":[],"effect_commands":[],"expected_state":{},"file_picker_contract":{}}',
        }
        manifest = {"artifact_schema_version": 1, "core_revision": CORE_REVISION,
                    "core_version": "0.97.0", "contract": {
                        "version": "0.96.2", "tag": "v0.96.2", "revision": REVISION},
                    "files": {name: {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
                              for name, raw in blobs.items()}}
        blobs["manifest.json"] = json.dumps(manifest).encode()
        return blobs

    def test_product_journeys_bind_exact_core_and_contract(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.journey_artifacts()
        calls = []
        def artifact(revision, filename):
            calls.append((revision, filename))
            return blobs[filename]
        raw, evidence = catalog.collect_assembly(self.root, self.fetch, artifact)
        self.assertEqual(RAW, raw)
        self.assertEqual("core-product-journey", evidence["fixture_category"])
        self.assertEqual(CORE_REVISION, evidence["core_revision"])
        self.assertEqual(REVISION, evidence["contract_revision"])
        self.assertEqual(["home"], evidence["inventory"]["screen_ids"])
        self.assertEqual({(CORE_REVISION, name) for name in blobs}, set(calls))
        self.assertFalse(any(project == "contract" for project, _, _ in self.calls))

    def test_product_manifest_mutations_are_rejected(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        mutations = [
            lambda m: m.update(core_revision="c" * 40),
            lambda m: m.update(core_version="0.97.1"),
            lambda m: m.update(artifact_schema_version=True),
            lambda m: m["contract"].update(revision="c" * 40),
            lambda m: m["contract"].update(version="0.96.3"),
            lambda m: m["files"].pop("presentation_contract_v1.json"),
            lambda m: m["files"]["screen_catalog_v1.json"].update(sha256="0" * 64),
        ]
        for index, mutation in enumerate(mutations):
            with self.subTest(index=index):
                blobs = self.journey_artifacts()
                manifest = json.loads(blobs["manifest.json"])
                mutation(manifest)
                blobs["manifest.json"] = json.dumps(manifest).encode()
                with self.assertRaises(catalog.CatalogError):
                    catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])

    def test_matching_hashes_do_not_allow_incomplete_product_catalog(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.journey_artifacts()
        name = "screen_catalog_inventory_v1.json"
        blobs[name] = b'{"schema_version":1,"screen_ids":["home","missing"]}'
        manifest = json.loads(blobs["manifest.json"])
        manifest["files"][name] = {"bytes": len(blobs[name]),
                                   "sha256": hashlib.sha256(blobs[name]).hexdigest()}
        blobs["manifest.json"] = json.dumps(manifest).encode()
        with self.assertRaisesRegex(catalog.CatalogError, "inventory mismatch"):
            catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])

    def with_extra_artifact(self, name, raw=b'{"schema_version":1}', recorded=None):
        blobs = self.journey_artifacts()
        blobs[name] = raw
        manifest = json.loads(blobs["manifest.json"])
        recorded = raw if recorded is None else recorded
        manifest["files"][name] = {"bytes": len(recorded),
                                   "sha256": hashlib.sha256(recorded).hexdigest()}
        blobs["manifest.json"] = json.dumps(manifest).encode()
        return blobs

    def test_core_may_publish_the_recovery_ceremony_fixture(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.with_extra_artifact("recovery_ceremony_v1.json")
        raw, evidence = catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])
        self.assertEqual(raw, RAW)
        self.assertIn("recovery_ceremony_v1.json", evidence["manifest"]["files"])

    def test_a_published_recovery_fixture_must_match_its_digest(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.with_extra_artifact("recovery_ceremony_v1.json", recorded=b"something else")
        with self.assertRaisesRegex(catalog.CatalogError, "artifact integrity mismatch"):
            catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])

    def test_a_file_the_contract_does_not_know_is_rejected(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.with_extra_artifact("unknown_v1.json")
        with self.assertRaisesRegex(catalog.CatalogError, "artifact file inventory mismatch"):
            catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])

    def test_the_recovery_fixture_cannot_replace_a_required_file(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.with_extra_artifact("recovery_ceremony_v1.json")
        manifest = json.loads(blobs["manifest.json"])
        manifest["files"].pop("presentation_contract_v1.json")
        blobs["manifest.json"] = json.dumps(manifest).encode()
        with self.assertRaisesRegex(catalog.CatalogError, "artifact file inventory mismatch"):
            catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name])

    def test_recovery_fixture_can_be_selected_for_download(self):
        with patch.object(catalog, "build_opener") as opener:
            opener.return_value.open.return_value.__enter__.return_value.read.return_value = b"{}"
            self.assertEqual(catalog.fetch_artifact(CORE_REVISION, "recovery_ceremony_v1.json"), b"{}")

    def test_verified_presentation_contract_can_be_written_beside_the_catalog(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.journey_artifacts()
        journeys = {}
        catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name], journeys)
        target = self.root / "replay" / "presentation-contract.json"
        catalog.write_presentation_contract(journeys, target)
        self.assertEqual(blobs["presentation_contract_v1.json"], target.read_bytes())

    def test_a_tampered_presentation_contract_is_never_handed_out(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        blobs = self.journey_artifacts()
        blobs["presentation_contract_v1.json"] += b" "
        journeys = {}
        with self.assertRaisesRegex(catalog.CatalogError, "artifact integrity mismatch"):
            catalog.collect_assembly(self.root, self.fetch, lambda rev, name: blobs[name], journeys)
        self.assertEqual({}, journeys)

    def test_a_legacy_assembly_has_no_presentation_contract_to_write(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        known = next(iter(catalog.LEGACY_CORES))
        def fetch(project, filename, ref):
            if project == "core":
                raw, _ = self.fetch(project, filename, "v0.97.0" if filename == "Cargo.toml" else CORE_REVISION)
                return raw, known
            return self.fetch(project, filename, ref)
        journeys = {}
        catalog.collect_assembly(self.root, fetch, journeys=journeys)
        target = self.root / "presentation-contract.json"
        with self.assertRaisesRegex(catalog.CatalogError, "needs a Core product-journey assembly"):
            catalog.write_presentation_contract(journeys, target)
        self.assertFalse(target.exists())

    def test_product_catalog_cannot_escape_screenshot_directory(self):
        for code_id in ("../outside", "/absolute", "a/b", "..", "a\\b"):
            with self.subTest(code_id=code_id):
                value = json.loads(RAW)
                value["screens"][0]["code_id"] = code_id
                with self.assertRaisesRegex(catalog.CatalogError, "invalid or duplicate"):
                    catalog.validate_catalog(json.dumps(value).encode())

    def test_deeply_nested_or_oversized_artifact_documents_are_rejected(self):
        for raw in (b"[" * 2000 + b"]" * 2000, b" " * (catalog.MAX_BYTES + 1)):
            with self.subTest(size=len(raw)):
                with self.assertRaises(catalog.CatalogError):
                    catalog.parse_document(raw)

    def test_known_legacy_core_is_explicitly_classified(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        known = next(iter(catalog.LEGACY_CORES))
        def fetch(project, filename, ref):
            if project == "core":
                raw, _ = self.fetch(project, filename, "v0.97.0" if filename == "Cargo.toml" else CORE_REVISION)
                return raw, known
            return self.fetch(project, filename, ref)
        raw, evidence = catalog.collect_assembly(self.root, fetch)
        self.assertEqual(RAW, raw)
        self.assertEqual("core-assembly-legacy", evidence["fixture_category"])
        self.assertEqual(known, evidence["core_revision"])

    def test_windows_uses_immutable_cabi_source_pin(self):
        (self.root / "cabi-version.json").write_text(json.dumps({
            "version": "0.99.1", "source_commit": CORE_REVISION}))
        self.assertEqual(("core", CORE_REVISION), catalog.pinned_ref(self.root))

    def test_new_core_cannot_fall_back_to_contract_catalog(self):
        (self.root / "core-ref").write_text("v0.97.0\n")
        def unavailable(revision, filename):
            raise catalog.CatalogError("artifact unavailable")
        with self.assertRaisesRegex(catalog.CatalogError, "artifact unavailable"):
            catalog.collect_assembly(self.root, self.fetch, unavailable)
        self.assertFalse(any(project == "contract" for project, _, _ in self.calls))

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
            if filename == "Cargo.lock":
                self.assertEqual(CORE_REVISION, ref)
                return (('[[package]]\nname="vauchi-contract"\nversion="0.96.2"\n'
                         f'source="git+https://gitlab.com/vauchi/contract.git?tag=v0.96.2#{REVISION}"\n').encode(), CORE_REVISION)
            self.assertEqual("v0.97.0", ref)
            return (b'[workspace.package]\nversion="0.97.0"\n[workspace.dependencies]\nvauchi-contract = { git = "https://gitlab.com/vauchi/contract.git", tag = "v0.96.2" }', CORE_REVISION)
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
        self.assertEqual("protocol-conformance-legacy", evidence["fixture_category"])
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
