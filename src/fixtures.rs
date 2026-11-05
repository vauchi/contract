// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Contract compatibility examples, compiled into the crate so a Rust consumer needs no
//! file path; other languages fetch the same files from `fixtures/`.

/// Legacy presentation compatibility example (`schema_version` 1).
/// Product journeys are owned and versioned by Core, independently of this API.
pub fn presentation_contract_v1_json() -> &'static str {
    include_str!("../fixtures/presentation_contract_v1.json")
}

/// Legacy compatibility batches for released consumers, not Core's current catalog.
pub fn screen_catalog_v1_json() -> &'static str {
    include_str!("../fixtures/screen_catalog_v1.json")
}
