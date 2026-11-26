// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use proptest::prelude::*;
use vauchi_contract::{BleAttributeValue, BlePreparationError};

// @internal — platform value bounds apply before native execution.
#[test]
fn attribute_values_accept_empty_and_exactly_512_bytes() {
    for bytes in [Vec::new(), vec![255; 512]] {
        let value = BleAttributeValue::new(bytes.clone()).expect("bounded value");
        assert_eq!(value.as_bytes(), bytes);
        assert_eq!(
            serde_json::to_value(&value).expect("encode"),
            serde_json::json!(bytes)
        );
    }
}

// @internal — constructed values cannot bypass the wire bound.
#[test]
fn constructing_an_attribute_value_rejects_the_513th_byte() {
    assert_eq!(
        BleAttributeValue::new(vec![0; 513]).expect_err("over limit"),
        BlePreparationError::TooManyItems { limit: 512 }
    );
}

// @internal — the parser rejects excess elements before decoding them.
#[test]
fn oversized_arrays_fail_before_decoding_the_excess_element() {
    for last in ["0", "256", "null", r#"{"unexpected":[1,2,3]}"#] {
        let prefix = vec!["0"; 512].join(",");
        let wire = format!("[{prefix},{last}]");
        let error = serde_json::from_str::<BleAttributeValue>(&wire).expect_err("over limit");
        assert_eq!(error.classify(), serde_json::error::Category::Data);
        assert!(
            error.to_string().starts_with("BLE list exceeds 512 items"),
            "{error}"
        );
    }
}

// @internal — byte values remain strict unsigned integers.
#[test]
fn invalid_attribute_elements_and_non_arrays_are_rejected() {
    for wire in [
        "[256]",
        "[-1]",
        "[1.5]",
        "[null]",
        "[true]",
        r#"["0"]"#,
        "null",
        "{}",
        r#""bytes""#,
    ] {
        let error = serde_json::from_str::<BleAttributeValue>(wire).expect_err("invalid bytes");
        assert_eq!(
            error.classify(),
            serde_json::error::Category::Data,
            "{wire}"
        );
    }
}

// @internal — logs must not disclose prepared attribute payloads.
#[test]
fn attribute_value_debug_reports_only_the_byte_count() {
    let value = BleAttributeValue::new(vec![42, 177, 0, 255]).expect("bounded value");
    assert_eq!(format!("{value:?}"), "BleAttributeValue { len: 4 }");
}

proptest! {
    // @internal — binary platform values round-trip without text conversion.
    #[test]
    fn every_bounded_binary_value_round_trips(bytes in proptest::collection::vec(any::<u8>(), 0..=512)) {
        let value = BleAttributeValue::new(bytes.clone()).expect("bounded value");
        let wire = serde_json::to_vec(&value).expect("encode");
        let decoded: BleAttributeValue = serde_json::from_slice(&wire).expect("decode");
        prop_assert_eq!(decoded.as_bytes(), bytes.as_slice());
        prop_assert_eq!(&decoded, &value);
        prop_assert_eq!(serde_json::to_vec(&decoded).expect("re-encode"), wire);
    }
}

// @internal — SDK generators receive an inline array with the same bound.
#[cfg(feature = "schema-gen")]
#[test]
fn the_attribute_value_schema_is_an_inline_bounded_byte_array() {
    let schema = serde_json::to_value(schemars::schema_for!(BleAttributeValue)).expect("schema");
    assert_eq!(schema["type"], "array");
    assert_eq!(schema["maxItems"], 512);
    assert_eq!(schema["items"]["type"], "integer");
    assert_eq!(schema["items"]["format"], "uint8");
    assert_eq!(schema["items"]["minimum"], 0.0);
    assert_eq!(schema["definitions"], serde_json::Value::Null);
}
