// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use serde::Deserialize;
use std::io::{self, Cursor};
use vauchi_contract::direct::{DirectFrameError, read_frame, write_frame};

#[derive(Deserialize)]
struct Fixture {
    schema_version: u8,
    valid: Vec<Valid>,
    invalid: Vec<Invalid>,
}

#[derive(Deserialize)]
struct Valid {
    payload: Vec<u8>,
    frame: Vec<u8>,
}

#[derive(Deserialize)]
struct Invalid {
    frame: Vec<u8>,
    error: String,
    consumed: u64,
}

// @scenario: generic_presentation_protocol.feature :: Invalid boundary input fails safely
#[test]
fn shared_direct_frames_match_the_authoritative_codec() {
    let fixture: Fixture =
        serde_json::from_str(include_str!("../fixtures/direct_frames_v1.json")).expect("fixture");
    assert_eq!(fixture.schema_version, 1);
    assert_eq!(fixture.valid.len(), 3);
    assert_eq!(fixture.invalid.len(), 7);
    for example in fixture.valid {
        let mut written = Vec::new();
        write_frame(&mut written, &example.payload).expect("valid frame");
        assert_eq!(written, example.frame);
        let mut input = Cursor::new(example.frame);
        assert_eq!(
            read_frame(&mut input).expect("valid payload"),
            example.payload
        );
        assert_eq!(input.position(), input.get_ref().len() as u64);
    }
    for example in fixture.invalid {
        let mut input = Cursor::new(example.frame);
        let reason = match read_frame(&mut input).expect_err("invalid frame") {
            DirectFrameError::InvalidMagic => "InvalidMagic",
            DirectFrameError::UnsupportedVersion(_) => "UnsupportedVersion",
            DirectFrameError::EmptyPayload => "EmptyPayload",
            DirectFrameError::PayloadTooLarge(_) => "PayloadTooLarge",
            DirectFrameError::Io(error) if error.kind() == io::ErrorKind::UnexpectedEof => {
                "Truncated"
            }
            error => panic!("unexpected frame error: {error}"),
        };
        assert_eq!(reason, example.error);
        assert_eq!(input.position(), example.consumed);
    }
}
