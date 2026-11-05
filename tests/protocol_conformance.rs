// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use serde_json::Value;
use vauchi_contract::{Command, Event, PresentationNode};

fn corpus() -> Value {
    serde_json::from_str(include_str!("../fixtures/protocol_conformance_v1.json")).unwrap()
}

// @internal — conformance examples use only generic contract types and defaults.
#[test]
fn focused_examples_decode_without_a_core_engine() {
    let corpus = corpus();
    assert_eq!(corpus["schema_version"], 1);
    let nodes: Vec<PresentationNode> = serde_json::from_value(corpus["nodes"].clone()).unwrap();
    let [
        PresentationNode::List {
            search_placeholder, ..
        },
    ] = nodes.as_slice()
    else {
        panic!("generic list example");
    };
    assert_eq!(search_placeholder, &None);
    let commands: Vec<Command> = serde_json::from_value(corpus["commands"].clone()).unwrap();
    let events: Vec<Event> = serde_json::from_value(corpus["events"].clone()).unwrap();
    assert_eq!(commands.len(), 2);
    assert_eq!(events.len(), 3);
    assert_eq!(serde_json::to_value(&commands).unwrap(), corpus["commands"]);
    assert_eq!(serde_json::to_value(&events).unwrap(), corpus["events"]);
}

// @internal — required unknown events and invalid opaque identifiers fail closed.
#[test]
fn invalid_event_examples_are_refused() {
    let corpus = corpus();
    let invalid = corpus["invalid_events"].as_array().unwrap();
    assert_eq!(invalid.len(), 2);
    for event in invalid {
        let error = serde_json::from_value::<Event>(event.clone()).unwrap_err();
        assert_eq!(error.classify(), serde_json::error::Category::Data);
    }
}
