// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Additive schemas do not make a receiver understand future enum tags.

use vauchi_contract::{Command, Event};

// @internal — decoder conformance, not application behavior.
#[test]
fn current_receiver_roundtrips_a_supported_command() {
    let wire = serde_json::to_string(&Command::QrRequestScan).expect("serialize command");
    assert_eq!(wire, r#""QrRequestScan""#);
    assert_eq!(
        serde_json::from_str::<Command>(&wire).expect("decode supported command"),
        Command::QrRequestScan
    );
}

// @internal — hypothetical future messages demonstrate compatibility direction.
#[test]
fn current_receiver_rejects_unknown_command_tags() {
    for wire in [r#""FutureCommand""#, r#"{"FutureCommand":{}}"#] {
        let error = serde_json::from_str::<Command>(wire).expect_err("unknown command must fail");
        assert_eq!(error.classify(), serde_json::error::Category::Data);
        assert!(
            error
                .to_string()
                .starts_with("unknown variant `FutureCommand`"),
            "unexpected error: {error}"
        );
    }
}

// @internal — unknown observations must not silently become accepted data.
#[test]
fn current_receiver_rejects_unknown_event_tags() {
    for wire in [r#""FutureEvent""#, r#"{"FutureEvent":{}}"#] {
        let error = serde_json::from_str::<Event>(wire).expect_err("unknown event must fail");
        assert_eq!(error.classify(), serde_json::error::Category::Data);
        assert!(
            error
                .to_string()
                .starts_with("unknown variant `FutureEvent`"),
            "unexpected error: {error}"
        );
    }
}
