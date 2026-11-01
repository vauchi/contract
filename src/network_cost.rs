// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! What the shell reports about the current network's cost
//! (`Event::NetworkCostChanged`); Core's settings read it.

/// What the current network costs, as the shell reports it.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NetworkCost {
    Unmetered,
    Metered,
    #[default]
    Unknown,
}
