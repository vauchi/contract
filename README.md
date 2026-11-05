<!-- SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me> -->
<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

# vauchi-contract

Browse the [generated vocabulary catalog](catalog/vocabulary.md) and
[contract review and growth-report guide](review/README.md) when changing
the protocol or reviewing feature impact.

The shell contract: the `Command` and `Event` protocol every Vauchi shell
renders or executes (ADR-066), as one package with its own version
(ADR-078). A display shell or a hardware shell depends on this crate, or
on the files below, and on nothing from Core; only an app links Core.

- `src/` — the Rust types, with `schema-gen` for the JSON Schema derive.
- `schema/vauchi-contract-v1.json` — the generated schema; `cargo test
  --features schema-gen` fails when it is stale, `cargo run --features
  schema-gen --bin gen-schema` regenerates it.
- `fixtures/protocol_conformance_v1.json` — focused generic examples of
  primitives, encoding, defaults, opaque interactions and hardware
  requests/results. Contract tests also exercise bounds and local callback
  lifetimes. These examples evolve with observable protocol semantics.
- The older presentation and screen-catalog files, exposed through
  `vauchi_contract::fixtures`, remain compatibility examples for released
  consumers. They are not the authoritative current Core product catalog.

Core owns and publishes product journeys as plain versioned data, naming
the generating Core revision and required contract version. Shells can
replay explicitly selected journeys without linking Core. They assert
faithful rendering/execution and reporting of supplied opaque ids, while
Core owns product expectations such as which screens offer recovery.
Standalone shell releases require contract conformance, not adoption of
the newest complete Core catalog. An app's pinned assembly selects its
journey evidence; it does not need a third fixture package.

Versioning: the contract's version line runs alongside Core's and starts
at 0.95.0 (owner, 2026-11-01); minors are additive, and the breaking-change
check compares the schema against the last release and refuses a removed
or retyped field, a removed variant or a tightened bound. The Rust enums
are exhaustive on purpose: Core is the one translator and must handle
every variant, so a new variant fails its build instead of falling through
a wildcard arm; a Rust shell that matches exhaustively gets the same
signal.
