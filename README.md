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
- `fixtures/` — the fixture corpus (`schema_version` 1): the presentation
  contract and the screen catalogue, compiled into the crate as
  `vauchi_contract::fixtures` and fetched as files by the Swift, Kotlin
  and C++ shells.

Versioning: the contract's version line runs alongside Core's and starts
at 0.95.0 (owner, 2026-11-01); minors are additive, and the breaking-change
check compares the schema against the last release and refuses a removed
or retyped field, a removed variant or a tightened bound. The Rust enums
are exhaustive on purpose: Core is the one translator and must handle
every variant, so a new variant fails its build instead of falling through
a wildcard arm; a Rust shell that matches exhaustively gets the same
signal.
