// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! adr-constraints "Events are observations" (ADR-066): a shell reports
//! what happened, and Core decides what it means. Every `Event` variant is
//! named for something observed, a past participle such as `QrScanned` or
//! `ValueChanged` or a measurement such as `AccelerometerData`, never an
//! intent such as `DeleteContact` (private#972, SC-64). This pins names
//! only; `domain_vocabulary_boundary` keeps domain words out of payloads.
//!
//! Run with:
//!   cargo test --features schema-gen --test event_observation_names

#![cfg(feature = "schema-gen")]

use schemars::schema_for;
use vauchi_contract::Event;

/// Final words that name an observation without an `-ed` ending. A new
/// one is a deliberate addition here, not a silent pass.
const OBSERVATION_NOUNS: &[&str] = &[
    "Read",
    "Ready",
    "Progress",
    "Data",
    "Result",
    "Error",
    "Unavailable",
    "Missing",
];

fn words(name: &str) -> Vec<&str> {
    let starts: Vec<usize> = name
        .char_indices()
        .filter(|(_, c)| c.is_ascii_uppercase())
        .map(|(i, _)| i)
        .chain([name.len()])
        .collect();
    starts.windows(2).map(|w| &name[w[0]..w[1]]).collect()
}

fn names_an_observation(name: &str) -> bool {
    let words = words(name);
    words
        .iter()
        .any(|word| word.len() > 3 && word.ends_with("ed"))
        || words
            .last()
            .is_some_and(|last| OBSERVATION_NOUNS.contains(last))
}

/// The variant names of an externally tagged enum's schema: a unit
/// variant is a string `enum`, a data variant an object with one required
/// key.
fn event_variants() -> Vec<String> {
    let schema = serde_json::to_value(schema_for!(Event)).expect("Event schema serializes");
    schema["oneOf"]
        .as_array()
        .expect("Event's schema is a oneOf over its variants")
        .iter()
        .flat_map(|variant| {
            let unit = variant["enum"].as_array().cloned().unwrap_or_default();
            let data = variant["required"].as_array().cloned().unwrap_or_default();
            unit.into_iter().chain(data)
        })
        .filter_map(|name| name.as_str().map(str::to_owned))
        .collect()
}

// @internal
#[test]
fn every_event_variant_names_an_observation() {
    let variants = event_variants();
    assert!(
        variants.iter().any(|name| name == "QrScanned") && variants.len() >= 50,
        "the schema walk must reach the Event variants, found {variants:?}"
    );

    let intents: Vec<&String> = variants
        .iter()
        .filter(|name| !names_an_observation(name))
        .collect();
    assert!(
        intents.is_empty(),
        "Event variants must name an observation, not an intent: {intents:?}"
    );
}

// @internal
#[test]
fn an_intent_is_not_an_observation() {
    for intent in ["DeleteContact", "SendCard", "OpenSettings", "ShareLink"] {
        assert!(!names_an_observation(intent), "{intent}");
    }
    for observation in [
        "ValueChanged",
        "FilePickedFromUser",
        "BleCharacteristicRead",
        "QrScanProgress",
    ] {
        assert!(names_an_observation(observation), "{observation}");
    }
}
