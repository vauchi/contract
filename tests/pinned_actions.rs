// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

//! A few actions a shell keeps in view under a surface's content, for a
//! decision that must not scroll away (vauchi/private#1304). Core sends
//! them only to a shell that reported it draws them; the others keep
//! the wire they know.

use serde_json::json;
use vauchi_contract::{
    ActionSpec, ActionTone, ContextBar, Event, InputMode, InteractionId, MotionPreference,
};

fn action(index: u8, label: &str) -> ActionSpec {
    ActionSpec {
        interaction_id: InteractionId::new(format!("presentation.pinned.7.{index}")).unwrap(),
        label: label.into(),
        accessibility_label: label.into(),
        icon_token: None,
        enabled: true,
        tone: ActionTone::Standard,
        shortcut: None,
    }
}

fn environment(pinned_actions: bool) -> Event {
    Event::PresentationEnvironmentChanged {
        available_width: 375,
        available_height: 667,
        input_modes: vec![InputMode::Touch],
        motion: MotionPreference::Full,
        color_scheme: None,
        pinned_actions,
    }
}

// @internal — a shell that predates the slot sees the bar it knows.
#[test]
fn a_bar_with_no_pinned_actions_keeps_its_old_wire_shape() {
    let wire = serde_json::to_value(ContextBar::default()).unwrap();

    assert_eq!(
        wire,
        json!({"back": null, "navigation": null, "primary": null, "secondary": null})
    );
}

// @internal — a Core that predates the slot still talks to a new shell.
#[test]
fn a_bar_from_a_core_without_the_slot_decodes_with_none_pinned() {
    let bar: ContextBar = serde_json::from_value(
        json!({"back": null, "navigation": null, "primary": null, "secondary": null}),
    )
    .unwrap();

    assert_eq!(bar.pinned, Vec::new());
}

// @internal — the shell draws them in Core's order.
#[test]
fn pinned_actions_cross_the_wire_in_their_order() {
    let bar = ContextBar {
        pinned: vec![action(0, "Start a new connection"), action(1, "Leave it")],
        ..ContextBar::default()
    };

    let wire = serde_json::to_value(&bar).unwrap();

    assert_eq!(
        wire["pinned"],
        json!([
            {
                "interaction_id": "presentation.pinned.7.0",
                "label": "Start a new connection",
                "accessibility_label": "Start a new connection",
                "icon_token": null,
                "enabled": true,
                "shortcut": null
            },
            {
                "interaction_id": "presentation.pinned.7.1",
                "label": "Leave it",
                "accessibility_label": "Leave it",
                "icon_token": null,
                "enabled": true,
                "shortcut": null
            }
        ])
    );
    assert_eq!(serde_json::from_value::<ContextBar>(wire).unwrap(), bar);
}

// @internal — a shell that does not report the capability does not have it.
#[test]
fn an_environment_report_without_the_capability_reads_as_not_drawing_pinned_actions() {
    let event: Event = serde_json::from_value(json!({"PresentationEnvironmentChanged": {
        "available_width": 375,
        "available_height": 667,
        "input_modes": ["touch"],
        "motion": "full"
    }}))
    .unwrap();

    assert_eq!(event, environment(false));
}

// @internal — the report is on the wire only when the shell draws them.
#[test]
fn an_environment_report_names_the_capability_only_when_the_shell_has_it() {
    let without = serde_json::to_value(environment(false)).unwrap();
    let with = serde_json::to_value(environment(true)).unwrap();

    assert_eq!(
        without["PresentationEnvironmentChanged"].get("pinned_actions"),
        None
    );
    assert_eq!(
        with["PresentationEnvironmentChanged"]["pinned_actions"],
        json!(true)
    );
    assert_eq!(
        serde_json::from_value::<Event>(with).unwrap(),
        environment(true)
    );
}
