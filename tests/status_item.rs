// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

//! A native status item (system tray), as the application menu: the shell
//! reports whether it can show one, Core prepares its copy and items, and
//! raising the window and native Quit stay with the shell (private#1029;
//! maintainer, 2026-11-11: the Qt app keeps its tray).

use serde_json::json;
use vauchi_contract::{
    ActionSpec, ActionTone, Command, CommandTarget, Event, InteractionId, StatusItemSpec, SurfaceId,
};

fn status_item() -> Command {
    Command::SetStatusItem {
        surface_id: SurfaceId::new("contacts").unwrap(),
        revision: 3,
        item: Some(StatusItemSpec {
            tooltip: "Vauchi".into(),
            show_window_label: "Show Vauchi".into(),
            items: vec![ActionSpec {
                interaction_id: InteractionId::new("presentation.status.3.0").unwrap(),
                label: "Import contacts".into(),
                accessibility_label: "Import contacts".into(),
                icon_token: None,
                enabled: true,
                tone: ActionTone::Standard,
                shortcut: None,
            }],
        }),
    }
}

// @internal — the status item is presentation: the display shell executes it.
#[test]
fn the_status_item_is_a_display_command() {
    assert_eq!(status_item().target(), CommandTarget::Display);
    assert_eq!(status_item().variant_name(), "SetStatusItem");
}

// @internal — the wire shape shells parse, including removal as a null item.
#[test]
fn the_status_item_carries_core_prepared_copy_on_the_wire() {
    assert_eq!(
        serde_json::to_value(status_item()).unwrap(),
        json!({"SetStatusItem": {
            "surface_id": "contacts",
            "revision": 3,
            "item": {
                "tooltip": "Vauchi",
                "show_window_label": "Show Vauchi",
                "items": [{
                    "interaction_id": "presentation.status.3.0",
                    "label": "Import contacts",
                    "accessibility_label": "Import contacts",
                    "icon_token": null,
                    "enabled": true,
                    "shortcut": null
                }]
            }
        }})
    );
    let removal: Command = serde_json::from_value(
        json!({"SetStatusItem": {"surface_id": "contacts", "revision": 4, "item": null}}),
    )
    .unwrap();
    assert!(matches!(
        removal,
        Command::SetStatusItem {
            item: None,
            revision: 4,
            ..
        }
    ));
}

// @internal — Core sends the item only to a shell that said it can show one.
#[test]
fn a_shell_reports_whether_it_can_show_a_status_item() {
    let event: Event =
        serde_json::from_value(json!({"StatusItemAvailabilityChanged": {"available": true}}))
            .unwrap();
    assert_eq!(
        event,
        Event::StatusItemAvailabilityChanged { available: true }
    );
}
