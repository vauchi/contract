<!-- SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me> -->
<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

# Reviewing contract evolution

Core owns application behavior; display and hardware shells implement
the shared vocabulary. Review whether a feature composes that vocabulary
before adding another primitive. A new hardware capability may require
new messages even when a new product screen does not.

## Review questions

1. Can existing primitives express the requirement clearly? If not,
   describe the missing reusable capability and why composition fails.
2. Which native handlers or renderers need new behavior? Name the affected
   shells and link their implementation or test evidence. Distinguish new
   behavior from dependency bumps, regeneration and fixture updates.
3. Does the feature require a contract-package release? Record this
   independently: a journey-fixture update can require a release without
   adding a protocol primitive.
4. For a vocabulary change, specify defaults, absent/null behavior,
   bounds, lifecycle and unsupported-capability behavior. Identify both
   wire compatibility and generated/source API compatibility; the
   structural report does not prove either one.
5. Add or reuse representative conformance samples. Keep product-journey
   assertions distinguishable from primitive/codec conformance. Current
   fixture ownership stays as defined by the existing architecture.

Use the MR template for a short review. Core-only feature work can record
its observation in a small follow-up contract MR even when the schema
does not change. Record representative reuse as well as extensions;
recording only contract-changing features biases the result.

## Vocabulary catalog

Browse [the generated vocabulary](../catalog/vocabulary.md). The catalog
enumerates every command and event tag and their supporting types, with
separate namespaces for the command and event schemas. References remain
symbolic rather than recursively expanded.

From the workspace root, regenerate and check it with:

```sh
just exec-in-repo contract 'python3 ci/contract-report.py catalog schema/vauchi-contract-v1.json --output catalog/vocabulary.md'
just exec-in-repo contract 'python3 ci/contract-report.py catalog schema/vauchi-contract-v1.json --check catalog/vocabulary.md'
```

The schema remains generated from Rust. Catalog output does not establish
custom Rust validation, native decoder defaults or renderer fidelity.

## Growth reports

Generate Markdown or JSON from a checkout:

```sh
just exec-in-repo contract 'python3 ci/contract-report.py report schema/vauchi-contract-v1.json'
just exec-in-repo contract 'python3 ci/contract-report.py report schema/vauchi-contract-v1.json --format json'
```

Supply `--baseline path/to/old-schema.json` for vocabulary deltas and
`--baseline-fixtures path/to/old-fixtures` for fixture deltas. Without a
baseline, the corresponding growth is explicitly not measured.
Use `--fixtures` and `--impacts` to select other input directories/files.

CI publishes both formats and the baseline schema as artifacts of
`contract:report`. MR comparisons use `CI_MERGE_REQUEST_DIFF_BASE_SHA`;
main comparisons use `CI_COMMIT_BEFORE_SHA`. A missing initial baseline
is reported as not measured. A supplied but unavailable baseline fails
the job instead of falling back to a different revision.

Interpret the dimensions separately:

- Vocabulary additions, removals and structural changes show where to
  review. Defaults and constraints count as changes; documentation and
  union ordering do not. Positional tuple order remains significant.
- Definition names are deduplicated by name for counting. Declarations
  remain separate per root; equal names do not imply equal definitions.
- Fixture bytes and hashes cover top-level JSON fixture files. They
  expose fixture churn without implying new protocol mechanics.
- File bytes are neither runtime message sizes nor final binary sizes.
  Measure latency, tree depth and resource use in consumer tests.

There is no arbitrary type-count or size cap. Investigate sustained
growth alongside renderer work, release coordination and reuse.

## Recording feature impact

Append an observation to [feature-impact.json](feature-impact.json).
Each entry needs a stable unique `id`, an HTTPS `evidence` link, a short
`reason`, a `shell_behavior` classification and a `shells` array.

Use these classifications:

| Value | Shell behavior | Contract release |
| --- | --- | --- |
| `unchanged` | Existing handlers suffice | No release needed for this change |
| `required` | New handler/renderer behavior needed | Contract-package release needed |
| `unknown` | Not independently reviewed yet | Release requirement not established |

`contract_release` may be omitted and then means `unknown`. A `required`
shell observation must name affected shells. An `unchanged` observation
must have an empty `shells` array. Unknown observations may name suspected
shells, but they remain excluded from the known denominator.

```json
{
  "id": "example-existing-primitives",
  "evidence": "https://example.org/merge-requests/42",
  "shell_behavior": "unchanged",
  "shells": [],
  "contract_release": "unknown",
  "reason": "Existing handlers suffice; release impact still needs review."
}
```

This example is illustrative; do not add it as an observation.

The primary ratio is changes requiring new shell behavior divided by
known reviewed changes. Reports also show unknown and total recorded
counts. No observations means **not measured**, not zero impact.

This is a review sample, not an automatic census of all product work.
The tool cannot establish missing coverage, verify linked claims or infer
native behavior from an unchanged schema. Update an observation when its
evidence resolves an unknown; do not fabricate historical classifications.
