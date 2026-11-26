// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use serde_json::{Value, json};
use vauchi_contract::{Command, CommandTarget};

fn example(index: usize) -> Value {
    let fixture: Value =
        serde_json::from_str(include_str!("../fixtures/prepared_ble_v1.json")).expect("fixture");
    assert_eq!(fixture["schema_version"], 1);
    fixture["commands"][index].clone()
}

fn prepared_roundtrip(index: usize) -> (Command, Value, Value) {
    let expected = example(index);
    let command: Command =
        serde_json::from_value(expected.clone()).expect("valid prepared command");
    let actual = serde_json::to_value(&command).expect("encode");
    (command, actual, expected)
}

// @internal — the hardware must receive complete supplied peripheral data.
#[test]
fn advertising_preserves_prepared_data_in_the_canonical_command() {
    let (command, actual, expected) = prepared_roundtrip(0);
    assert_eq!(command.variant_name(), "BleStartAdvertising");
    assert_eq!(command.target(), CommandTarget::Hardware);
    assert_eq!(actual, expected);
}

// @internal — the hardware must receive complete supplied central data.
#[test]
fn connect_preserves_prepared_data_in_the_canonical_command() {
    let (command, actual, expected) = prepared_roundtrip(1);
    assert_eq!(command.variant_name(), "BleConnect");
    assert_eq!(command.target(), CommandTarget::Hardware);
    assert_eq!(actual, expected);
}

// @internal — absent prepared data retains the released wire representation.
#[test]
fn legacy_ble_commands_keep_identical_serialized_bytes() {
    for wire in [
        r#"{"BleStartAdvertising":{"service_uuid":"native-service","payload":[0,1,2,3]}}"#,
        r#"{"BleConnect":{"device_id":"native-peer"}}"#,
    ] {
        let command: Command = serde_json::from_str(wire).expect("legacy command");
        assert_eq!(serde_json::to_string(&command).expect("encode"), wire);
        let mut explicit_null: Value = serde_json::from_str(wire).expect("legacy JSON");
        let body = explicit_null
            .as_object_mut()
            .expect("command")
            .values_mut()
            .next()
            .expect("body");
        body["prepared"] = Value::Null;
        let command: Command = serde_json::from_value(explicit_null).expect("absent optional data");
        assert_eq!(serde_json::to_string(&command).expect("encode"), wire);
    }
}

// @internal — invalid prepared data cannot silently select a legacy path.
#[test]
fn malformed_prepared_data_is_rejected_instead_of_ignored() {
    for (index, name) in [(0, "BleStartAdvertising"), (1, "BleConnect")] {
        for bad in [json!({}), json!(true), json!("prepared"), json!([])] {
            let mut wire = example(index);
            wire[name]["prepared"] = bad;
            let error =
                serde_json::from_value::<Command>(wire).expect_err("invalid prepared operation");
            assert_eq!(
                error.classify(),
                serde_json::error::Category::Data,
                "{name}"
            );
        }
    }
}

// @internal — nested bounds remain enforced at the public command envelope.
#[test]
fn prepared_command_decoding_keeps_nested_limits() {
    for (index, pointer, bad) in [
        (
            0,
            "/BleStartAdvertising/prepared/readiness_conditions/0/value_prefix",
            json!(vec![0; 513]),
        ),
        (
            0,
            "/BleStartAdvertising/prepared/service/characteristics/0/uuid",
            json!(vec![0; 15]),
        ),
        (
            1,
            "/BleConnect/prepared/retry/busy_or_timeout_delays_millis",
            json!(vec![0; 33]),
        ),
        (
            1,
            "/BleConnect/prepared/subscriptions/0/value",
            json!(vec![0; 513]),
        ),
    ] {
        let mut wire = example(index);
        *wire.pointer_mut(pointer).expect("prepared field") = bad;
        let error = serde_json::from_value::<Command>(wire).expect_err("nested bounds");
        assert_eq!(
            error.classify(),
            serde_json::error::Category::Data,
            "{pointer}"
        );
    }
}

// @internal — schema consumers see additive optional fields and all prepared definitions.
#[cfg(feature = "schema-gen")]
#[test]
fn the_schema_exposes_optional_prepared_fields_on_existing_variants() {
    let schema = vauchi_contract::schema::generate();
    let root = &schema["command"];
    let alternatives = root
        .get("oneOf")
        .or_else(|| root.get("anyOf"))
        .expect("command variants")
        .as_array()
        .expect("variants");
    for (name, kind) in [
        ("BleStartAdvertising", "BlePeripheralSpec"),
        ("BleConnect", "BleCentralSpec"),
    ] {
        let body = alternatives
            .iter()
            .find_map(|item| item.get("properties")?.get(name))
            .expect("variant");
        assert!(body["properties"].get("prepared").is_some(), "{name}");
        assert!(
            !body["required"]
                .as_array()
                .expect("required")
                .contains(&json!("prepared")),
            "{name}"
        );
        assert_eq!(root["definitions"][kind]["type"], "object");
    }
}
