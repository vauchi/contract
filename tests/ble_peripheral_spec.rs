// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use proptest::prelude::*;
use serde_json::json;
use vauchi_contract::{
    BleAdvertisedUuid, BleAdvertisementSpec, BleAdvertisingMode, BleAdvertisingParameters,
    BleAdvertisingTxPower, BleAttributeValue, BleDescriptorWriteCondition, BleGattServiceSpec,
    BlePeripheralSpec, BlePreparationError,
};

fn parameters() -> BleAdvertisingParameters {
    BleAdvertisingParameters {
        mode: BleAdvertisingMode::LowLatency,
        tx_power: BleAdvertisingTxPower::Medium,
        connectable: true,
        include_device_name: false,
        timeout_millis: 0,
    }
}

fn uuids(count: usize) -> Vec<BleAdvertisedUuid> {
    (0..count)
        .map(|index| BleAdvertisedUuid::Uuid16([index as u8, 255]))
        .collect()
}

fn readiness(count: usize) -> Vec<BleDescriptorWriteCondition> {
    (0..count)
        .map(|index| BleDescriptorWriteCondition {
            characteristic_uuid: [index as u8; 16],
            descriptor_uuid: [42; 16],
            value_prefix: BleAttributeValue::new(vec![1]).expect("bounded prefix"),
        })
        .collect()
}

fn peripheral(uuid_count: usize, condition_count: usize) -> BlePeripheralSpec {
    BlePeripheralSpec::new(
        BleAdvertisementSpec::new(uuids(uuid_count), parameters()).expect("bounded advertisement"),
        BleGattServiceSpec::new([42; 16], true, vec![]).expect("bounded service"),
        readiness(condition_count),
    )
    .expect("bounded peripheral")
}

// @internal — prepared UUID widths are explicit; normalized observations cannot be advertised.
#[test]
fn advertised_uuids_preserve_each_explicit_width_and_reject_normalized_values() {
    for (uuid, wire) in [
        (
            BleAdvertisedUuid::Uuid16([1, 255]),
            json!({"Uuid16":[1,255]}),
        ),
        (
            BleAdvertisedUuid::Uuid32([1, 2, 3, 4]),
            json!({"Uuid32":[1,2,3,4]}),
        ),
        (
            BleAdvertisedUuid::Uuid128([42; 16]),
            json!({"Uuid128":vec![42;16]}),
        ),
    ] {
        assert_eq!(serde_json::to_value(uuid).expect("encode"), wire);
        assert_eq!(
            serde_json::from_value::<BleAdvertisedUuid>(wire).expect("decode"),
            uuid
        );
    }
    let error = serde_json::from_value::<BleAdvertisedUuid>(json!({"Normalized":vec![42;16]}))
        .expect_err("observation-only variant");
    assert_eq!(error.classify(), serde_json::error::Category::Data);
}

// @internal — the hardware receives the complete native advertising parameters.
#[test]
fn advertising_parameters_and_readiness_prefixes_round_trip_exactly() {
    let value = peripheral(2, 1);
    let wire = serde_json::to_value(&value).expect("encode");
    assert_eq!(
        wire["advertisement"]["parameters"],
        json!({
            "mode":"LowLatency","tx_power":"Medium","connectable":true,
            "include_device_name":false,"timeout_millis":0
        })
    );
    assert_eq!(
        wire["advertisement"]["service_uuids"],
        json!([{"Uuid16":[0,255]},{"Uuid16":[1,255]}])
    );
    assert_eq!(
        wire["readiness_conditions"],
        json!([{
            "characteristic_uuid":vec![0;16],"descriptor_uuid":vec![42;16],"value_prefix":[1]
        }])
    );
    assert_eq!(
        serde_json::from_value::<BlePeripheralSpec>(wire).expect("decode"),
        value
    );
    assert_eq!(value.readiness_conditions(), readiness(1));
    assert_eq!(value.advertisement.service_uuids(), uuids(2));
}

// @internal — constructed advertising and readiness arrays cannot bypass their limits.
#[test]
fn peripheral_constructors_enforce_both_collection_limits() {
    let value = peripheral(32, 16);
    assert_eq!(value.advertisement.service_uuids(), uuids(32));
    assert_eq!(value.readiness_conditions(), readiness(16));
    assert_eq!(
        BleAdvertisementSpec::new(uuids(33), parameters()).expect_err("UUID bound"),
        BlePreparationError::TooManyItems { limit: 32 }
    );
    assert_eq!(
        BlePeripheralSpec::new(
            BleAdvertisementSpec::new(vec![], parameters()).expect("empty advertisement"),
            BleGattServiceSpec::new([42; 16], true, vec![]).expect("service"),
            readiness(17)
        )
        .expect_err("readiness bound"),
        BlePreparationError::TooManyItems { limit: 16 }
    );
}

// @internal — excess setup data is rejected before decoding another object.
#[test]
fn peripheral_decoder_rejects_excess_uuid_and_readiness_elements() {
    for (pointer, limit) in [
        ("/advertisement/service_uuids", 32),
        ("/readiness_conditions", 16),
    ] {
        let mut wire = serde_json::to_value(peripheral(32, 16)).expect("encode");
        wire.pointer_mut(pointer)
            .expect("array")
            .as_array_mut()
            .expect("array")
            .push(json!({"unexpected":true}));
        let error = serde_json::from_value::<BlePeripheralSpec>(wire).expect_err("bounded list");
        assert!(
            error
                .to_string()
                .starts_with(&format!("BLE list exceeds {limit} items")),
            "{error}"
        );
    }
}

// @internal — UUID widths, closed settings and unsigned native times remain strict.
#[test]
fn malformed_peripheral_fields_are_rejected() {
    let valid = serde_json::to_value(peripheral(1, 1)).expect("encode");
    for (pointer, bad) in [
        ("/advertisement/service_uuids/0", json!({"Uuid16":[1]})),
        ("/advertisement/service_uuids/0", json!({"Uuid32":[1,2,3]})),
        (
            "/advertisement/service_uuids/0",
            json!({"Uuid128":vec![1;17]}),
        ),
        ("/advertisement/parameters/mode", json!("Unknown")),
        ("/advertisement/parameters/tx_power", json!("Unknown")),
        ("/advertisement/parameters/timeout_millis", json!(-1)),
        (
            "/advertisement/parameters/timeout_millis",
            json!(4_294_967_296u64),
        ),
        (
            "/readiness_conditions/0/characteristic_uuid",
            json!(vec![0; 15]),
        ),
        (
            "/readiness_conditions/0/descriptor_uuid",
            json!(vec![0; 17]),
        ),
        ("/readiness_conditions/0/value_prefix", json!(vec![0; 513])),
    ] {
        let mut wire = valid.clone();
        *wire.pointer_mut(pointer).expect("field") = bad;
        let error = serde_json::from_value::<BlePeripheralSpec>(wire).expect_err("invalid field");
        assert_eq!(
            error.classify(),
            serde_json::error::Category::Data,
            "{pointer}"
        );
    }
}

proptest! {
    // @internal — DTO bounds do not imply radio capability or valid cross-field references.
    #[test]
    fn bounded_peripheral_values_round_trip(uuid_count in 0usize..=32, conditions in 0usize..=16,
        timeout in any::<u32>(), connectable in any::<bool>(), include_name in any::<bool>()) {
        let mut value = peripheral(uuid_count,conditions);
        value.advertisement.parameters.timeout_millis=timeout;
        value.advertisement.parameters.connectable=connectable;
        value.advertisement.parameters.include_device_name=include_name;
        let bytes = serde_json::to_vec(&value).expect("encode");
        prop_assert_eq!(serde_json::from_slice::<BlePeripheralSpec>(&bytes).expect("decode"),value);
    }
}

// @internal — all SDKs receive the same collection and prefix-byte limits.
#[cfg(feature = "schema-gen")]
#[test]
fn peripheral_schema_exposes_all_collection_bounds() {
    let schema = serde_json::to_value(schemars::schema_for!(BlePeripheralSpec)).expect("schema");
    assert_eq!(schema["properties"]["readiness_conditions"]["maxItems"], 16);
    assert_eq!(
        schema["definitions"]["BleAdvertisementSpec"]["properties"]["service_uuids"]["maxItems"],
        32
    );
    assert_eq!(
        schema["definitions"]["BleDescriptorWriteCondition"]["properties"]["value_prefix"]["maxItems"],
        512
    );
}
