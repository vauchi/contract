// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The frame a [`crate::Command::DirectSend`] payload travels in over a
//! wired or local link. Core chooses the framing (ADR-077); the contract
//! holds the one codec Core and the hardware shells use (private#1029).
//!
//! A frame is the magic `VXCH`, version 1, the payload's length as four
//! big-endian bytes, then the payload. Both sides exchange one frame each:
//! the initiator writes first, the responder reads first, so neither waits
//! on the other.

use std::io::{self, Read, Write};

/// The largest payload a frame carries. Exchange payloads are about 300
/// bytes; the bound is checked before any payload byte is read.
pub const MAX_DIRECT_PAYLOAD: u32 = 65_536;

const MAGIC: &[u8; 4] = b"VXCH";
const VERSION: u8 = 1;

/// Why a frame could not be written or read.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum DirectFrameError {
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),
    #[error("invalid frame magic")]
    InvalidMagic,
    #[error("unsupported frame version: {0}")]
    UnsupportedVersion(u8),
    #[error("payload too large: {0} bytes (max {MAX_DIRECT_PAYLOAD})")]
    PayloadTooLarge(u32),
    #[error("empty payload")]
    EmptyPayload,
}

/// Writes `payload` as one frame and flushes.
pub fn write_frame(link: &mut impl Write, payload: &[u8]) -> Result<(), DirectFrameError> {
    if payload.is_empty() {
        return Err(DirectFrameError::EmptyPayload);
    }
    let len = u32::try_from(payload.len()).unwrap_or(u32::MAX);
    if len > MAX_DIRECT_PAYLOAD {
        return Err(DirectFrameError::PayloadTooLarge(len));
    }
    link.write_all(MAGIC)?;
    link.write_all(&[VERSION])?;
    link.write_all(&len.to_be_bytes())?;
    link.write_all(payload)?;
    link.flush()?;
    Ok(())
}

/// Reads one frame and returns its payload.
pub fn read_frame(link: &mut impl Read) -> Result<Vec<u8>, DirectFrameError> {
    let mut magic = [0u8; 4];
    link.read_exact(&mut magic)?;
    if &magic != MAGIC {
        return Err(DirectFrameError::InvalidMagic);
    }
    let mut version = [0u8; 1];
    link.read_exact(&mut version)?;
    if version[0] != VERSION {
        return Err(DirectFrameError::UnsupportedVersion(version[0]));
    }
    let mut len = [0u8; 4];
    link.read_exact(&mut len)?;
    let len = u32::from_be_bytes(len);
    if len > MAX_DIRECT_PAYLOAD {
        return Err(DirectFrameError::PayloadTooLarge(len));
    }
    let mut payload = vec![0u8; len as usize];
    link.read_exact(&mut payload)?;
    Ok(payload)
}

/// Sends `ours` and returns the peer's payload, in the order the role sets.
pub fn exchange(
    link: &mut (impl Read + Write),
    ours: &[u8],
    is_initiator: bool,
) -> Result<Vec<u8>, DirectFrameError> {
    if is_initiator {
        write_frame(link, ours)?;
        read_frame(link)
    } else {
        let theirs = read_frame(link)?;
        write_frame(link, ours)?;
        Ok(theirs)
    }
}
