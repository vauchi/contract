// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The JSON Schema of the protocol, generated from the types so it cannot
//! drift from them; `schema/vauchi-contract-v1.json` is its committed form.

use schemars::schema_for;

use crate::{Command, Event};

/// The schema document: `schema_version`, then the `Command` and `Event`
/// schemas as schemars emits them.
pub fn generate() -> serde_json::Value {
    serde_json::json!({
        "schema_version": 1,
        "command": serde_json::to_value(schema_for!(Command)).expect("command schema serializes"),
        "event": serde_json::to_value(schema_for!(Event)).expect("event schema serializes"),
    })
}
