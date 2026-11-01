// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The committed schema is the generated schema. A stale file would let a
//! shell build against a protocol Core no longer speaks (ADR-078 item 8).

#![cfg(feature = "schema-gen")]

#[test]
fn the_committed_schema_is_the_generated_one() {
    let committed: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/schema/vauchi-contract-v1.json"))
            .expect("schema/vauchi-contract-v1.json is committed"),
    )
    .expect("the committed schema is JSON");
    let generated = vauchi_contract::schema::generate();
    assert_eq!(
        committed, generated,
        "schema/vauchi-contract-v1.json is stale: run `cargo run --features schema-gen --bin gen-schema`"
    );
    assert_eq!(generated["schema_version"], 1);
    assert!(generated["command"]["oneOf"].is_array() || generated["command"]["anyOf"].is_array());
}
