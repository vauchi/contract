// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use serde_json::{Value, json};
use std::io::{self, BufRead};
use vauchi_contract::{Command, Event, event_from_json};

fn main() {
    for line in io::stdin().lock().lines() {
        let line = line.expect("probe stdin");
        let request: Value = serde_json::from_str(&line).expect("probe request");
        let input = request["json"].as_str().expect("raw JSON input");
        let decoded: Result<Value, String> = match request["kind"].as_str() {
            Some("command") => serde_json::from_str::<Command>(input)
                .map(|value| serde_json::to_value(value).unwrap())
                .map_err(|error| error.to_string()),
            Some("event") => serde_json::from_str::<Event>(input)
                .map(|value| serde_json::to_value(value).unwrap())
                .map_err(|error| error.to_string()),
            Some("boundary") => event_from_json(input)
                .map(|value| serde_json::to_value(value).unwrap())
                .map_err(|error| error.to_string()),
            _ => Err("invalid probe kind".into()),
        };
        let result = match decoded {
            Ok(value) => json!({"id": request["id"], "ok": true, "value": value}),
            Err(error) => json!({"id": request["id"], "ok": false, "error": error}),
        };
        println!("{result}");
    }
}
