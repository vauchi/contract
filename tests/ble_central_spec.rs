// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use proptest::prelude::*;
use serde_json::json;
use vauchi_contract::{
    BleAttributeValue, BleCentralSpec, BleCharacteristicWriteSpec, BleGattRetrySpec,
    BlePreparationError, BleSubscriptionSpec, BleWriteMode,
};

fn retry(count: usize) -> BleGattRetrySpec {
    BleGattRetrySpec::new(vec![400; count], vec![150; count], vec![150; count], 1500)
        .expect("bounded retries")
}

fn central(
    required: usize,
    subscriptions: usize,
    writes: usize,
    delays: usize,
) -> Result<BleCentralSpec, BlePreparationError> {
    BleCentralSpec::new(
        [42; 16],
        247,
        (0..required).map(|index| [index as u8; 16]).collect(),
        (0..subscriptions)
            .map(|index| BleSubscriptionSpec {
                characteristic_uuid: [index as u8; 16],
                descriptor_uuid: [43; 16],
                value: BleAttributeValue::new(vec![1, 0]).expect("bounded descriptor value"),
            })
            .collect(),
        (0..writes)
            .map(|index| BleCharacteristicWriteSpec {
                characteristic_uuid: [index as u8; 16],
                mode: if index % 2 == 0 {
                    BleWriteMode::WithResponse
                } else {
                    BleWriteMode::WithoutResponse
                },
            })
            .collect(),
        retry(delays),
    )
}

// @internal — supplied ordering, exact descriptor bytes and native timing remain intact.
#[test]
fn central_setup_round_trips_its_complete_native_parameters() {
    let value = central(2, 2, 2, 2).expect("bounded central");
    let wire = serde_json::to_value(&value).expect("encode");
    assert_eq!(wire["service_uuid"], json!(vec![42; 16]));
    assert_eq!(wire["requested_mtu"], 247);
    assert_eq!(
        wire["required_characteristics"],
        json!([vec![0; 16], vec![1; 16]])
    );
    assert_eq!(
        wire["subscriptions"][1],
        json!({"characteristic_uuid":vec![1;16],"descriptor_uuid":vec![43;16],"value":[1,0]})
    );
    assert_eq!(wire["write_modes"][0]["mode"], "WithResponse");
    assert_eq!(wire["write_modes"][1]["mode"], "WithoutResponse");
    assert_eq!(
        wire["retry"],
        json!({"incomplete_discovery_delays_millis":[400,400],
        "missing_attribute_delays_millis":[150,150],"busy_or_timeout_delays_millis":[150,150],"operation_timeout_millis":1500})
    );
    assert_eq!(
        serde_json::from_value::<BleCentralSpec>(wire).expect("decode"),
        value
    );
    assert_eq!(value.required_characteristics(), &[[0; 16], [1; 16]]);
    assert_eq!(value.subscriptions()[1].value.as_bytes(), &[1, 0]);
    assert_eq!(value.write_modes()[1].mode, BleWriteMode::WithoutResponse);
    assert_eq!(
        value.retry.incomplete_discovery_delays_millis(),
        &[400, 400]
    );
    assert_eq!(value.retry.missing_attribute_delays_millis(), &[150, 150]);
    assert_eq!(value.retry.busy_or_timeout_delays_millis(), &[150, 150]);
}

// @internal — no constructed central list can bypass the attribute-count ceilings.
#[test]
fn central_constructors_enforce_each_sixteen_item_limit() {
    let value = central(16, 16, 16, 32).expect("exact limits");
    assert_eq!(value.required_characteristics().len(), 16);
    assert_eq!(value.subscriptions().len(), 16);
    assert_eq!(value.write_modes().len(), 16);
    for counts in [(17, 16, 16), (16, 17, 16), (16, 16, 17)] {
        assert_eq!(
            central(counts.0, counts.1, counts.2, 32).expect_err("too many items"),
            BlePreparationError::TooManyItems { limit: 16 }
        );
    }
}

// @internal — each retry budget is bounded independently of its delays.
#[test]
fn retry_constructors_reject_a_thirty_third_delay() {
    let value = retry(32);
    assert_eq!(value.incomplete_discovery_delays_millis(), vec![400; 32]);
    assert_eq!(value.missing_attribute_delays_millis(), vec![150; 32]);
    assert_eq!(value.busy_or_timeout_delays_millis(), vec![150; 32]);
    for position in 0..3 {
        let mut values = [vec![1; 32], vec![2; 32], vec![3; 32]];
        values[position].push(4);
        assert_eq!(
            BleGattRetrySpec::new(
                values[0].clone(),
                values[1].clone(),
                values[2].clone(),
                1500
            )
            .expect_err("retry bound"),
            BlePreparationError::TooManyItems { limit: 32 }
        );
    }
}

// @internal — oversized setup arrays fail before decoding an excess element.
#[test]
fn central_decoder_rejects_every_oversized_collection() {
    for (pointer, limit) in [
        ("/required_characteristics", 16),
        ("/subscriptions", 16),
        ("/write_modes", 16),
        ("/retry/incomplete_discovery_delays_millis", 32),
        ("/retry/missing_attribute_delays_millis", 32),
        ("/retry/busy_or_timeout_delays_millis", 32),
    ] {
        let mut wire =
            serde_json::to_value(central(16, 16, 16, 32).expect("exact limits")).expect("encode");
        wire.pointer_mut(pointer)
            .expect("array")
            .as_array_mut()
            .expect("array")
            .push(json!({"unexpected":true}));
        let error = serde_json::from_value::<BleCentralSpec>(wire).expect_err("oversized array");
        assert!(
            error
                .to_string()
                .starts_with(&format!("BLE list exceeds {limit} items")),
            "{error}"
        );
    }
}

// @internal — scalar widths and the write-mode enum must not be coerced.
#[test]
fn malformed_central_fields_are_rejected() {
    let valid = serde_json::to_value(central(1, 1, 1, 1).expect("central")).expect("encode");
    for (pointer, bad) in [
        ("/service_uuid", json!(vec![0; 15])),
        ("/required_characteristics/0", json!(vec![0; 17])),
        ("/subscriptions/0/characteristic_uuid", json!(vec![0; 15])),
        ("/subscriptions/0/descriptor_uuid", json!(vec![0; 17])),
        ("/subscriptions/0/value", json!(vec![0; 513])),
        ("/write_modes/0/characteristic_uuid", json!(vec![0; 15])),
        ("/write_modes/0/mode", json!("Unknown")),
        ("/requested_mtu", json!(-1)),
        ("/requested_mtu", json!(65_536)),
        ("/retry/incomplete_discovery_delays_millis/0", json!(-1)),
        (
            "/retry/missing_attribute_delays_millis/0",
            json!(4_294_967_296u64),
        ),
        ("/retry/busy_or_timeout_delays_millis/0", json!(1.5)),
        ("/retry/operation_timeout_millis", json!(-1)),
    ] {
        let mut wire = valid.clone();
        *wire.pointer_mut(pointer).expect("field") = bad;
        let error = serde_json::from_value::<BleCentralSpec>(wire).expect_err("invalid field");
        assert_eq!(
            error.classify(),
            serde_json::error::Category::Data,
            "{pointer}"
        );
    }
}

proptest! {
    // @internal — schema bounds do not imply native MTU or timing support.
    #[test]
    fn bounded_central_values_round_trip(count in 0usize..=16, delays in 0usize..=32, mtu in any::<u16>(), timeout in any::<u32>()) {
        let mut value=central(count,count,count,delays).expect("bounded setup");
        value.requested_mtu=mtu;
        value.retry.operation_timeout_millis=timeout;
        let bytes=serde_json::to_vec(&value).expect("encode");
        prop_assert_eq!(serde_json::from_slice::<BleCentralSpec>(&bytes).expect("decode"),value);
    }
}

// @internal — generated SDKs receive all central and retry collection limits.
#[cfg(feature = "schema-gen")]
#[test]
fn central_schema_preserves_every_collection_bound() {
    let schema = serde_json::to_value(schemars::schema_for!(BleCentralSpec)).expect("schema");
    for field in ["required_characteristics", "subscriptions", "write_modes"] {
        assert_eq!(schema["properties"][field]["maxItems"], 16, "{field}");
    }
    for field in [
        "incomplete_discovery_delays_millis",
        "missing_attribute_delays_millis",
        "busy_or_timeout_delays_millis",
    ] {
        assert_eq!(
            schema["definitions"]["BleGattRetrySpec"]["properties"][field]["maxItems"], 32,
            "{field}"
        );
    }
    assert_eq!(
        schema["definitions"]["BleSubscriptionSpec"]["properties"]["value"]["maxItems"],
        512
    );
}
