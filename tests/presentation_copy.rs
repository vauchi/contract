// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later
//! Core sends the copy a shell used to look up itself (ADR-066 "commands are
//! complete", private#1029 4d.7d, owner 2026-11-03): the window title, a
//! searchable list's placeholder, and a QR capture's placeholder and submit
//! label. Each is optional, as ADR-078 item 8 keeps minors additive: a Core
//! that omits it, and every fixture recorded before it, still reads.
use serde_json::{Value, json};
use vauchi_contract::{AccessibilitySpec, PresentationNode, PresentationProfile};

fn profile() -> Value {
    json!({
        "window_class": "expanded",
        "pane_layout": "single",
        "primary_surface": "home",
        "detail_surface": null,
        "active_surface": "home"
    })
}

fn list(extra: Value) -> Value {
    let mut node = json!({
        "id": "contacts",
        "label": null,
        "rows": [],
        "searchable": true,
        "paging": null,
        "accessibility": AccessibilitySpec::label("Contacts"),
    });
    node.as_object_mut()
        .unwrap()
        .extend(extra.as_object().unwrap().clone());
    json!({ "List": node })
}

fn qr_capture(extra: Value) -> Value {
    let mut node = json!({
        "id": "scan",
        "payloads": [],
        "purpose": "capture",
        "label": null,
        "accessibility": AccessibilitySpec::label("Scan a code"),
    });
    node.as_object_mut()
        .unwrap()
        .extend(extra.as_object().unwrap().clone());
    json!({ "Qr": node })
}

fn round_trip<T: serde::de::DeserializeOwned + serde::Serialize>(value: Value) -> (T, Value) {
    let decoded: T = serde_json::from_value(value).expect("reads");
    let back = serde_json::to_value(&decoded).expect("serializes");
    (decoded, back)
}

// @scenario: generic_presentation_protocol.feature :: Invalid boundary input fails safely
#[test]
fn payloads_without_the_copy_still_read_and_stay_without_it() {
    let (profile, back): (PresentationProfile, _) = round_trip(profile());
    assert_eq!(profile.window_title, None);
    assert!(back.get("window_title").is_none());

    let (node, back): (PresentationNode, _) = round_trip(list(json!({})));
    let PresentationNode::List {
        search_placeholder, ..
    } = node
    else {
        panic!("a list node");
    };
    assert_eq!(search_placeholder, None);
    assert!(back["List"].get("search_placeholder").is_none());

    let (node, back): (PresentationNode, _) = round_trip(qr_capture(json!({})));
    let PresentationNode::Qr {
        capture_placeholder,
        capture_submit_label,
        ..
    } = node
    else {
        panic!("a QR node");
    };
    assert_eq!((capture_placeholder, capture_submit_label), (None, None));
    assert!(back["Qr"].get("capture_placeholder").is_none());
    assert!(back["Qr"].get("capture_submit_label").is_none());
}

// @scenario: generic_presentation_protocol.feature :: Every shell renders the same prepared presentation
#[test]
fn the_copy_core_sends_reaches_the_shell_unchanged() {
    let mut with_title = profile();
    with_title["window_title"] = json!("Vauchi");
    let (profile, back): (PresentationProfile, _) = round_trip(with_title.clone());
    assert_eq!(profile.window_title.as_deref(), Some("Vauchi"));
    assert_eq!(back, with_title);

    let sent = list(json!({ "search_placeholder": "Search contacts" }));
    let (node, back): (PresentationNode, _) = round_trip(sent.clone());
    let PresentationNode::List {
        search_placeholder, ..
    } = node
    else {
        panic!("a list node");
    };
    assert_eq!(search_placeholder.as_deref(), Some("Search contacts"));
    assert_eq!(back, sent);

    let sent = qr_capture(json!({
        "capture_placeholder": "Paste the code's text",
        "capture_submit_label": "Use this code",
    }));
    let (node, back): (PresentationNode, _) = round_trip(sent.clone());
    let PresentationNode::Qr {
        capture_placeholder,
        capture_submit_label,
        ..
    } = node
    else {
        panic!("a QR node");
    };
    assert_eq!(
        capture_placeholder.as_deref(),
        Some("Paste the code's text")
    );
    assert_eq!(capture_submit_label.as_deref(), Some("Use this code"));
    assert_eq!(back, sent);
}
