# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Exercise the catalog and growth report through their command-line API."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "contract-report.py"
SCHEMA = {
    "schema_version": 1,
    "command": {
        "oneOf": [
            {"enum": ["Stop", "Pause"]},
            {"type": "object", "properties": {"Show": {
                "type": "object", "required": ["content"], "properties": {
                    "content": {"$ref": "#/definitions/Node"},
                    "tone": {"type": "string", "default": "normal"},
                },
            }}, "required": ["Show"]},
        ],
        "definitions": {"Node": {"type": "object", "properties": {
            "children": {"type": "array", "items": {"$ref": "#/definitions/Node"}},
        }}},
    },
    "event": {"oneOf": [{"enum": ["Done"]}], "definitions": {
        "Node": {"type": "string"},
    }},
}


class ContractReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.schema = self.write("schema.json", SCHEMA)
        self.impacts = self.write("impacts.json", {"version": 1, "changes": []})

    def write(self, name, value):
        path = self.root / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def run_cli(self, mode, *args, expected=0):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), mode, str(self.schema), *map(str, args)],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
        return result

    def report(self, *args):
        return json.loads(self.run_cli(
            "report", "--impacts", self.impacts, "--format", "json", *args,
        ).stdout)

    def test_catalog_lists_every_tag_and_preserves_recursive_and_qualified_types(self):
        result = self.run_cli("catalog")
        for label in ("Stop", "Pause", "Show", "Done", "command.Node", "event.Node"):
            self.assertIn(f"`{label}`", result.stdout)
        self.assertIn("#/definitions/Node", result.stdout)
        self.assertIn('"default":"normal"', result.stdout)
        self.assertIn("Schema defaults", result.stdout)
        self.assertEqual(result.stdout, self.run_cli("catalog").stdout)

    def test_freshness_detects_stale_catalog_then_accepts_generated_catalog(self):
        target = self.root / "catalog.md"
        target.write_text("stale\n", encoding="utf-8")
        stale = self.run_cli("catalog", "--check", target, expected=1)
        self.assertIn("catalog is stale", stale.stderr)
        self.run_cli("catalog", "--output", target)
        fresh = self.run_cli("catalog", "--check", target)
        self.assertEqual("catalog is current\n", fresh.stdout)

    def test_counts_do_not_expand_recursive_refs_or_merge_different_root_types(self):
        report = self.report()
        self.assertEqual(3, report["counts"]["command_variants"])
        self.assertEqual(1, report["counts"]["event_variants"])
        self.assertEqual(1, report["counts"]["definition_names"])
        self.assertEqual(2, report["counts"]["definition_declarations"])
        self.assertEqual(None, report["growth"])
        self.assertEqual(len(self.schema.read_bytes()), report["schema_bytes"])

    def test_growth_detects_added_removed_and_changed_types_without_order_noise(self):
        old = copy.deepcopy(SCHEMA)
        old["command"]["oneOf"][0]["enum"] = ["Stop", "Retired"]
        old["command"]["definitions"]["Node"]["properties"]["children"]["maxItems"] = 4
        baseline = self.write("baseline.json", old)
        growth = self.report("--baseline", baseline)["growth"]
        self.assertEqual(["command.Pause"], growth["added"])
        self.assertEqual(["command.Retired"], growth["removed"])
        self.assertEqual(["command.definitions.Node"], growth["changed"])
        self.assertEqual(0, growth["counts"]["command_variants"])
        reordered = copy.deepcopy(SCHEMA)
        reordered["command"]["oneOf"].reverse()
        reordered["command"]["oneOf"][1]["enum"].reverse()
        reordered["command"]["description"] = "Documentation only"
        no_change = self.report("--baseline", self.write("reordered.json", reordered))["growth"]
        self.assertEqual([], no_change["changed"])
        self.assertEqual([], no_change["added"])
        self.assertEqual([], no_change["removed"])

    def test_feature_impact_preserves_unknowns_and_only_counts_recorded_changes(self):
        changes = [
            {"id": "reused", "evidence": "https://example.org/mr/1", "shell_behavior": "unchanged",
             "shells": [], "reason": "Uses existing nodes"},
            {"id": "new", "evidence": "https://example.org/mr/2", "shell_behavior": "required",
             "shells": ["apple-display"], "reason": "Adds a renderer primitive"},
            {"id": "pending", "evidence": "https://example.org/issue/3", "shell_behavior": "unknown",
             "shells": [], "reason": "Not reviewed yet"},
        ]
        self.write("impacts.json", {"version": 1, "changes": changes})
        impact = self.report()["feature_impact"]
        self.assertEqual(3, impact["recorded"])
        self.assertEqual(1, impact["unchanged"])
        self.assertEqual(1, impact["required"])
        self.assertEqual(1, impact["unknown"])
        self.assertEqual(2, impact["known"])
        self.assertEqual(0.5, impact["required_share_of_known"])
        self.assertEqual(changes, impact["changes"])
        markdown = self.run_cli("report", "--impacts", self.impacts).stdout
        self.assertIn("recorded changes only", markdown)
        self.assertIn("unknown", markdown)

    def test_growth_preserves_tuple_order_and_data_named_like_schema_annotations(self):
        for old_body, new_body in (
            ({"type": "array", "items": [{"type": "string"}, {"type": "integer"}]},
             {"type": "array", "items": [{"type": "integer"}, {"type": "string"}]}),
            ({"type": "object", "properties": {"title": {"type": "string"}}},
             {"type": "object", "properties": {"title": {"type": "integer"}}}),
            ({"default": {"description": "before"}}, {"default": {"description": "after"}}),
        ):
            with self.subTest(old=old_body, new=new_body):
                old, new = copy.deepcopy(SCHEMA), copy.deepcopy(SCHEMA)
                old["command"]["definitions"]["Node"] = old_body
                new["command"]["definitions"]["Node"] = new_body
                self.write("schema.json", new)
                growth = self.report("--baseline", self.write("old.json", old))["growth"]
                self.assertEqual(["command.definitions.Node"], growth["changed"])

    def test_root_constraints_and_variant_envelopes_are_reported(self):
        old = copy.deepcopy(SCHEMA)
        old["command"]["additionalProperties"] = False
        old["command"]["oneOf"][1]["additionalProperties"] = False
        growth = self.report("--baseline", self.write("old.json", old))["growth"]
        self.assertEqual(["command.Show"], growth["changed"])
        self.assertEqual(["command"], growth["envelopes_changed"])

    def test_empty_feature_history_is_not_reported_as_zero_impact(self):
        impact = self.report()["feature_impact"]
        self.assertEqual(0, impact["recorded"])
        self.assertEqual(None, impact["required_share_of_known"])
        self.assertIn("not measured", self.run_cli("report", "--impacts", self.impacts).stdout)

    def test_fixture_only_release_is_separate_from_new_shell_behavior(self):
        self.write("impacts.json", {"version": 1, "changes": [{
            "id": "fixture-only", "evidence": "https://example.org/mr/19",
            "shell_behavior": "unchanged", "shells": [],
            "contract_release": "required", "reason": "A journey fixture changed",
        }]})
        impact = self.report()["feature_impact"]
        self.assertEqual(0.0, impact["required_share_of_known"])
        self.assertEqual({"required": 1, "unchanged": 0, "unknown": 0}, impact["contract_release"])
        self.assertIn("release", self.run_cli("report", "--impacts", self.impacts).stdout)

    def test_invalid_evidence_and_ambiguous_observations_fail(self):
        good = {"id": "change", "evidence": "https://example.org/mr/1", "shell_behavior": "required",
                "shells": ["qt-display"], "reason": "New primitive"}
        for update in ({"shell_behavior": "maybe"}, {"shells": []}, {"reason": ""},
                       {"evidence": "javascript:alert(1)"}, {"id": ""}):
            with self.subTest(update=update):
                self.write("impacts.json", {"version": 1, "changes": [good | update]})
                result = self.run_cli("report", "--impacts", self.impacts, expected=2)
                self.assertIn("invalid feature impact", result.stderr)
        self.write("impacts.json", {"version": 1, "changes": [good, good]})
        self.assertIn("duplicate", self.run_cli(
            "report", "--impacts", self.impacts, expected=2,
        ).stderr)

    def test_malformed_schema_and_unrecognized_union_arm_fail_instead_of_undercounting(self):
        for value in ({}, {"schema_version": 1, "command": {}, "event": {}},
                      SCHEMA | {"command": {"oneOf": [{"type": "number"}]}}):
            with self.subTest(value=value):
                self.write("schema.json", value)
                result = self.run_cli("catalog", expected=2)
                self.assertIn("invalid contract schema", result.stderr)
        self.schema.write_text("{", encoding="utf-8")
        self.assertIn("invalid JSON", self.run_cli("catalog", expected=2).stderr)

    def test_catalog_escapes_markdown_and_html_from_schema_labels(self):
        hostile = copy.deepcopy(SCHEMA)
        hostile["event"]["oneOf"] = [{"enum": ["a|b\n<script>`"]}]
        self.write("schema.json", hostile)
        output = self.run_cli("catalog").stdout
        self.assertNotIn("<script>", output)
        self.assertIn("&lt;script&gt;", output)
        self.assertIn("&#124;", output)


if __name__ == "__main__":
    unittest.main()
