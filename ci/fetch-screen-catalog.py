# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Fetch the full catalog at the consumer's contract pin, with provenance."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

MAX_BYTES = 8 * 1024 * 1024
TAG = r"v\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?"
SHA = r"[0-9a-f]{40}"

# This released revision predates inventory files; its required IDs stay frozen.
LEGACY_REVISION = "1f6c1b971bef1edb6fffab21c0bbdaa6664729fa"
LEGACY_SCREEN_IDS = frozenset("""
onboarding
my_info-empty
contacts-empty
exchange-no_groups
lock
my_info
contacts
contact_detail
contact_edit
contact_visibility
verify_fingerprint
exchange
settings
settings_advanced
settings_appearance
settings_accessibility
help
backup
device_linking
device_management
duress_pin
change_password
decoy_contacts
emergency_broadcast
emergency_shred
delivery_status
recovery
recovery_help
groups
group_detail
tags
places
privacy
support
entry_detail
contact_duplicates
contact_merge
activity_log
archived_contacts
device_replacement
avatar_editor
recovery_claim_review
link_exchange
nfc_exchange
direct_transport
multi_stage_exchange-glance
multi_stage_exchange-hover
multi_stage_exchange-hover-placed
ble_exchange-magic
ble_exchange-bump
ble_exchange-shake
form_dialog-add_field
form_dialog-edit_field
form_dialog-edit_name
form_dialog-edit_relay_url
form_dialog-create_group
form_dialog-rename_group
onboarding-de
my_info-de
contacts-de
settings-de
""".split())


class CatalogError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise CatalogError(message)


def pinned_ref(repo):
    lock = repo / "Cargo.lock"
    if lock.exists():
        packages = tomllib.loads(lock.read_text()).get("package", [])
        contracts = [p for p in packages if p["name"] == "vauchi-contract"]
        require(len(contracts) == 1, "Cargo.lock must pin exactly one contract package")
        source = contracts[0].get("source", "")
        match = re.fullmatch(r"git\+https://gitlab.com/vauchi/contract(?:\.git)?\?[^#]+#(" + SHA + ")", source)
        require(match is not None, "contract must resolve to a Git commit in Cargo.lock")
        return "contract", match[1]
    core_ref = repo / "core-ref"
    project = repo / "project.yml"
    gradle = repo / "app/build.gradle.kts"
    if core_ref.exists():
        versions = [line.strip() for line in core_ref.read_text().splitlines()
                    if line.strip() and not line.lstrip().startswith("#")]
    elif project.exists():
        versions = ["v" + value for value in re.findall(
            r'vauchi-platform-swift\.git\s*\n\s*version:\s*"([^"]+)"', project.read_text())]
    elif gradle.exists():
        versions = ["v" + value for value in re.findall(
            r'app\.vauchi:vauchi-platform:([^"\s]+)', gradle.read_text())]
    else:
        raise CatalogError("no supported consumer dependency pin found")
    require(len(set(versions)) == 1 and re.fullmatch(TAG, versions[0]) is not None,
            "consumer must pin one exact Core release")
    return "core", versions[0]


def fetch_file(project, filename, ref):
    api = os.environ.get("CI_API_V4_URL", "https://gitlab.com/api/v4")
    require(api.startswith("https://"), "GitLab API must use HTTPS")
    url = (f"{api}/projects/vauchi%2F{project}/repository/files/"
           f"{quote(filename, safe='')}?ref={quote(ref, safe='')}")
    headers = {}
    if os.environ.get("CI_JOB_TOKEN"):
        headers["JOB-TOKEN"] = os.environ["CI_JOB_TOKEN"]
    try:
        with urlopen(Request(url, headers=headers), timeout=30) as response:
            raw = response.read(MAX_BYTES + 1)
        require(len(raw) <= MAX_BYTES, "GitLab file response exceeds size limit")
        value = json.loads(raw)
        require(value["encoding"] == "base64", "unexpected file encoding")
        content = base64.b64decode(value["content"], validate=True)
        revision = value["commit_id"]
        require(re.fullmatch(SHA, revision) is not None, "invalid file revision")
        return content, revision
    except (URLError, OSError, ValueError, KeyError, TypeError) as error:
        raise CatalogError(f"cannot fetch {project}/{filename} at {ref}") from error


def validate_inventory(raw, actual_ids):
    require(len(raw) <= MAX_BYTES, "inventory exceeds size limit")
    try:
        inventory = json.loads(raw)
    except (ValueError, TypeError) as error:
        raise CatalogError("malformed inventory") from error
    require(type(inventory) is dict and set(inventory) == {"schema_version", "screen_ids"}
            and type(inventory["schema_version"]) is int and inventory["schema_version"] == 1,
            "invalid inventory schema")
    ids = inventory["screen_ids"]
    require(type(ids) is list and ids and all(type(item) is str and item for item in ids),
            "invalid inventory IDs")
    require(len(set(ids)) == len(ids), "duplicate inventory IDs")
    missing, unexpected = set(ids) - actual_ids, actual_ids - set(ids)
    require(not missing and not unexpected,
            f"catalog inventory mismatch: missing {sorted(missing)}, unexpected {sorted(unexpected)}")


def collect(repo, fetch=fetch_file):
    project, ref = pinned_ref(repo)
    evidence = {"schema_version": 1}
    if project == "core":
        manifest, revision = fetch("core", "Cargo.toml", ref)
        evidence.update(core_ref=ref, core_revision=revision)
        dependency = tomllib.loads(manifest.decode())["workspace"]["dependencies"]["vauchi-contract"]
        require(dependency.get("git") == "https://gitlab.com/vauchi/contract.git",
                "Core contract dependency has an unexpected repository")
        ref = dependency.get("rev", dependency.get("tag", ""))
        require(re.fullmatch(f"(?:{TAG}|{SHA})", ref) is not None,
                "Core must pin an exact contract tag or revision")
    raw, revision = fetch("contract", "fixtures/screen_catalog_v1.json", ref)
    require(re.fullmatch(SHA, revision) is not None, "invalid contract revision")
    require(not re.fullmatch(SHA, ref) or ref == revision, "contract revision mismatch")
    require(len(raw) <= MAX_BYTES, "catalog exceeds size limit")
    try:
        catalog = json.loads(raw)
        require(type(catalog) is dict and catalog.get("schema_version") == 1,
                "invalid catalog schema")
        screens = catalog.get("screens")
        require(type(screens) is list and len(screens) > 0, "full catalog must contain screens")
        ids = set()
        for screen in screens:
            require(type(screen) is dict and type(screen.get("code_id")) is str
                    and screen["code_id"] and screen["code_id"] not in ids
                    and type(screen.get("commands")) is list and screen["commands"],
                    "invalid or duplicate catalog screen")
            ids.add(screen["code_id"])
    except (ValueError, TypeError) as error:
        raise CatalogError("malformed catalog") from error
    if revision == LEGACY_REVISION:
        inventory_raw = json.dumps({"schema_version": 1, "screen_ids": sorted(LEGACY_SCREEN_IDS)}).encode()
        inventory_source = "frozen:" + revision
    else:
        inventory_raw, inventory_revision = fetch(
            "contract", "fixtures/screen_catalog_inventory_v1.json", revision)
        require(inventory_revision == revision, "inventory revision mismatch")
        inventory_source = "contract:" + revision
    validate_inventory(inventory_raw, ids)
    evidence.update(inventory_source=inventory_source,
                    inventory_sha256=hashlib.sha256(inventory_raw).hexdigest())
    evidence.update(contract_ref=ref, contract_revision=revision,
                    sha256=hashlib.sha256(raw).hexdigest(), screens=len(screens))
    return raw, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        raw, evidence = collect(args.repo)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(raw)
        args.output.with_suffix(".provenance.json").write_text(json.dumps(evidence, indent=2) + "\n")
    except (CatalogError, OSError, ValueError, KeyError, TypeError) as error:
        print("catalog evidence: " + (str(error) if isinstance(error, CatalogError)
                                    else "invalid input or output"), file=sys.stderr)
        return 1
    print(f"Full catalog: {evidence['screens']} screens at {evidence['contract_revision']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
