// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later
//! The frame a `DirectSend` payload travels in over a wired or local link
//! (USB tethering, local TCP): Core chooses the framing (ADR-077), and the
//! contract holds the one codec Core and every hardware shell use
//! (private#1029 4d.7c, owner 2026-11-04). The bytes are the ones Core's
//! `tcp_transport` has always written: "VXCH", version 1, a big-endian
//! length, the payload.
use std::io::{self, Cursor, Read, Write};

use vauchi_contract::direct::{
    DirectFrameError, MAX_DIRECT_PAYLOAD, exchange, read_frame, write_frame,
};

/// One side of a link: reads what the peer sent, records what it writes.
struct Duplex {
    incoming: Cursor<Vec<u8>>,
    outgoing: Vec<u8>,
}

impl Read for Duplex {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        self.incoming.read(buf)
    }
}

impl Write for Duplex {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.outgoing.write(buf)
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn framed(payload: &[u8]) -> Vec<u8> {
    let mut bytes = Vec::new();
    write_frame(&mut bytes, payload).expect("frame");
    bytes
}

// @internal — the wire bytes Core shipped before the codec moved here.
#[test]
fn a_frame_is_magic_version_length_and_payload() {
    assert_eq!(
        framed(b"abc"),
        [b'V', b'X', b'C', b'H', 1, 0, 0, 0, 3, b'a', b'b', b'c']
    );
}

// @internal
#[test]
fn every_payload_size_up_to_the_limit_round_trips() {
    for len in [1, 2, 300, 4096, MAX_DIRECT_PAYLOAD as usize] {
        let payload: Vec<u8> = (0..len).map(|i| (i % 251) as u8).collect();
        let back = read_frame(&mut Cursor::new(framed(&payload))).expect("read back");
        assert_eq!(back, payload, "length {len}");
    }
}

// @scenario: generic_presentation_protocol.feature :: Invalid boundary input fails safely
#[test]
fn malformed_frames_are_refused_before_any_payload_is_read() {
    let mut bad_magic = framed(b"abc");
    bad_magic[0] = b'X';
    assert!(matches!(
        read_frame(&mut Cursor::new(bad_magic)),
        Err(DirectFrameError::InvalidMagic)
    ));

    let mut bad_version = framed(b"abc");
    bad_version[4] = 2;
    assert!(matches!(
        read_frame(&mut Cursor::new(bad_version)),
        Err(DirectFrameError::UnsupportedVersion(2))
    ));

    let mut oversized = b"VXCH\x01".to_vec();
    oversized.extend_from_slice(&(MAX_DIRECT_PAYLOAD + 1).to_be_bytes());
    assert!(matches!(
        read_frame(&mut Cursor::new(oversized)),
        Err(DirectFrameError::PayloadTooLarge(len)) if len == MAX_DIRECT_PAYLOAD + 1
    ));

    let mut truncated = framed(b"abcdef");
    truncated.truncate(truncated.len() - 2);
    assert!(matches!(
        read_frame(&mut Cursor::new(truncated)),
        Err(DirectFrameError::Io(error)) if error.kind() == io::ErrorKind::UnexpectedEof
    ));
}

// @scenario: generic_presentation_protocol.feature :: Invalid boundary input fails safely
#[test]
fn an_empty_or_oversized_payload_is_never_written() {
    let mut sink = Vec::new();
    assert!(matches!(
        write_frame(&mut sink, b""),
        Err(DirectFrameError::EmptyPayload)
    ));
    let too_big = vec![0u8; MAX_DIRECT_PAYLOAD as usize + 1];
    assert!(matches!(
        write_frame(&mut sink, &too_big),
        Err(DirectFrameError::PayloadTooLarge(_))
    ));
    assert!(sink.is_empty(), "nothing reaches the link");
}

// @internal — the initiator sends first, the responder answers.
#[test]
fn the_initiator_sends_first_and_the_responder_answers() {
    let mut initiator = Duplex {
        incoming: Cursor::new(framed(b"theirs")),
        outgoing: Vec::new(),
    };
    assert_eq!(
        exchange(&mut initiator, b"ours", true).expect("exchange"),
        b"theirs"
    );
    assert_eq!(initiator.outgoing, framed(b"ours"));

    let mut responder = Duplex {
        incoming: Cursor::new(framed(b"theirs")),
        outgoing: Vec::new(),
    };
    assert_eq!(
        exchange(&mut responder, b"ours", false).expect("exchange"),
        b"theirs"
    );
    assert_eq!(responder.outgoing, framed(b"ours"));

    let mut refused = Duplex {
        incoming: Cursor::new(b"nonsense!".to_vec()),
        outgoing: Vec::new(),
    };
    assert!(exchange(&mut refused, b"ours", false).is_err());
    assert!(
        refused.outgoing.is_empty(),
        "a responder answers only a valid frame"
    );
}
