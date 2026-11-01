// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Writes `schema/vauchi-contract-v1.json` from the types.

fn main() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/schema/vauchi-contract-v1.json");
    let text = serde_json::to_string_pretty(&vauchi_contract::schema::generate()).expect("schema serializes");
    std::fs::write(path, text + "\n").expect("write the schema file");
    println!("wrote {path}");
}
