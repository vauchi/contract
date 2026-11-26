// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use proptest::prelude::*;
use serde_json::{Value, json};
use vauchi_contract::{
    BleAttributeValue, BleGattCharacteristicSpec, BleGattDescriptorSpec, BleGattPermissions,
    BleGattProperties, BleGattServiceSpec, BlePreparationError,
};

fn descriptor(index: u8, bytes: Vec<u8>) -> BleGattDescriptorSpec {
    BleGattDescriptorSpec {
        uuid: [index; 16],
        permissions: BleGattPermissions {
            read: true,
            write: true,
        },
        value: BleAttributeValue::new(bytes).expect("bounded descriptor value"),
    }
}

fn characteristic(index: u8, count: usize, bytes: Vec<u8>) -> BleGattCharacteristicSpec {
    BleGattCharacteristicSpec::new(
        [index; 16],
        BleGattProperties {
            read: true,
            write: false,
            write_without_response: false,
            notify: true,
            indicate: false,
        },
        BleGattPermissions {
            read: true,
            write: false,
        },
        BleAttributeValue::new(bytes).expect("bounded initial value"),
        (0..count)
            .map(|index| descriptor(index as u8, vec![1, 0]))
            .collect(),
    )
    .expect("bounded descriptors")
}

// @internal — prepared attributes retain native mechanics without interpreting bytes.
#[test]
fn prepared_gatt_values_preserve_uuids_flags_and_complete_byte_values() {
    let attribute = characteristic(17, 1, vec![231, 232, 233]);
    let service =
        BleGattServiceSpec::new([42; 16], true, vec![attribute.clone()]).expect("service");
    let wire = serde_json::to_value(&service).expect("encode");
    assert_eq!(
        wire,
        json!({
        "uuid": vec![42; 16], "primary": true,
            "characteristics": [{
            "uuid": vec![17; 16],
                "properties": {"read":true,"write":false,"write_without_response":false,"notify":true,"indicate":false},
                "permissions": {"read":true,"write":false}, "initial_value":[231,232,233],
            "descriptors":[{"uuid":vec![0;16],"permissions":{"read":true,"write":true},"value":[1,0]}]
            }]
        })
    );
    assert_eq!(
        serde_json::from_value::<BleGattServiceSpec>(wire).expect("decode"),
        service
    );
    assert_eq!(service.characteristics(), &[attribute]);
    assert_eq!(
        service.characteristics()[0].descriptors(),
        &[descriptor(0, vec![1, 0])]
    );
    let debug = format!("{service:?}");
    assert!(debug.contains("BleAttributeValue { len: 3 }"));
    assert!(
        !debug.contains("231"),
        "prepared byte values leaked: {debug}"
    );
}

// @internal — constructed lists cannot bypass the canonical descriptor ceiling.
#[test]
fn characteristics_accept_four_descriptors_and_reject_five() {
    assert_eq!(characteristic(1, 4, vec![]).descriptors().len(), 4);
    let error = BleGattCharacteristicSpec::new(
        [1; 16],
        BleGattProperties {
            read: false,
            write: false,
            write_without_response: false,
            notify: false,
            indicate: false,
        },
        BleGattPermissions {
            read: false,
            write: false,
        },
        BleAttributeValue::new(vec![]).expect("empty bytes"),
        (0..5).map(|index| descriptor(index, vec![])).collect(),
    )
    .expect_err("too many descriptors");
    assert_eq!(error, BlePreparationError::TooManyItems { limit: 4 });
}

// @internal — constructed services cannot bypass the characteristic ceiling.
#[test]
fn services_accept_sixteen_characteristics_and_reject_seventeen() {
    let items: Vec<_> = (0..16)
        .map(|index| characteristic(index, 0, vec![]))
        .collect();
    let service = BleGattServiceSpec::new([1; 16], true, items.clone()).expect("bounded service");
    assert_eq!(service.characteristics(), items);
    let error = BleGattServiceSpec::new(
        [1; 16],
        true,
        (0..17)
            .map(|index| characteristic(index, 0, vec![]))
            .collect(),
    )
    .expect_err("too many characteristics");
    assert_eq!(error, BlePreparationError::TooManyItems { limit: 16 });
}

// @internal — excess native setup data is rejected before another object is parsed.
#[test]
fn oversized_gatt_lists_fail_before_decoding_an_excess_object() {
    let mut service = serde_json::to_value(
        BleGattServiceSpec::new(
            [1; 16],
            true,
            (0..16)
                .map(|index| characteristic(index, 4, vec![]))
                .collect(),
        )
        .expect("bounded service"),
    )
    .expect("encode");
    service["characteristics"]
        .as_array_mut()
        .expect("array")
        .push(json!({"unexpected":true}));
    let error = serde_json::from_value::<BleGattServiceSpec>(service.clone())
        .expect_err("characteristic bound");
    assert!(
        error.to_string().starts_with("BLE list exceeds 16 items"),
        "{error}"
    );
    service["characteristics"]
        .as_array_mut()
        .expect("array")
        .pop();
    service["characteristics"][0]["descriptors"]
        .as_array_mut()
        .expect("array")
        .push(json!({"unexpected":true}));
    let error =
        serde_json::from_value::<BleGattServiceSpec>(service).expect_err("descriptor bound");
    assert!(
        error.to_string().starts_with("BLE list exceeds 4 items"),
        "{error}"
    );
}

// @internal — all GATT addresses have exactly 128 bits in network order.
#[test]
fn gatt_addresses_reject_truncated_and_overlong_uuids() {
    let valid = serde_json::to_value(
        BleGattServiceSpec::new([1; 16], true, vec![characteristic(2, 1, vec![])])
            .expect("service"),
    )
    .expect("encode");
    for pointer in [
        "/uuid",
        "/characteristics/0/uuid",
        "/characteristics/0/descriptors/0/uuid",
    ] {
        for count in [0, 15, 17] {
            let mut wire = valid.clone();
            *wire.pointer_mut(pointer).expect("uuid") = Value::Array(vec![json!(0); count]);
            let error =
                serde_json::from_value::<BleGattServiceSpec>(wire).expect_err("bad UUID width");
            assert_eq!(
                error.classify(),
                serde_json::error::Category::Data,
                "{pointer}: {count}"
            );
        }
    }
}

proptest! {
    // @internal — bounded prepared GATT structures preserve arbitrary binary values.
    #[test]
    fn bounded_gatt_services_round_trip(count in 0usize..=16, descriptors in 0usize..=4,
        bytes in proptest::collection::vec(any::<u8>(),0..=512), primary in any::<bool>()) {
        let value = BleGattServiceSpec::new([42;16],primary,
            (0..count).map(|index| characteristic(index as u8,descriptors,bytes.clone())).collect()).expect("bounded service");
        let wire = serde_json::to_vec(&value).expect("encode");
        let decoded: BleGattServiceSpec = serde_json::from_slice(&wire).expect("decode");
        prop_assert_eq!(decoded, value);
    }
}

// @internal — every SDK sees the same nested list and byte limits.
#[cfg(feature = "schema-gen")]
#[test]
fn prepared_gatt_schema_preserves_all_nested_bounds() {
    let schema = serde_json::to_value(schemars::schema_for!(BleGattServiceSpec)).expect("schema");
    assert_eq!(schema["properties"]["characteristics"]["maxItems"], 16);
    assert_eq!(
        schema["definitions"]["BleGattCharacteristicSpec"]["properties"]["descriptors"]["maxItems"],
        4
    );
    assert_eq!(
        schema["definitions"]["BleGattDescriptorSpec"]["properties"]["value"]["maxItems"],
        512
    );
    assert_eq!(
        schema["definitions"]["BleGattCharacteristicSpec"]["properties"]["initial_value"]["maxItems"],
        512
    );
}
