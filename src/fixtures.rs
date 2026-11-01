// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The fixture corpus, compiled into the crate so a Rust consumer needs no
//! file path; other languages fetch the same files from `fixtures/`.

/// The presentation contract: initial commands, steps and expected state
/// (`schema_version` 1).
pub fn presentation_contract_v1_json() -> &'static str {
    include_str!("../fixtures/presentation_contract_v1.json")
}

/// Every screen the presentation layer can emit, for render parity tests.
pub fn screen_catalog_v1_json() -> &'static str {
    include_str!("../fixtures/screen_catalog_v1.json")
}
