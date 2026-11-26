// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use super::{BleAttributeValue, BlePreparationError, bounded_list};
use serde::{Deserialize, Serialize};

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BleWriteMode {
    WithResponse,
    WithoutResponse,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleCharacteristicWriteSpec {
    pub characteristic_uuid: [u8; 16],
    pub mode: BleWriteMode,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleSubscriptionSpec {
    pub characteristic_uuid: [u8; 16],
    pub descriptor_uuid: [u8; 16],
    pub value: BleAttributeValue,
}

/// Core selects separate delay sequences for each native retry condition.
/// A rejected operation or missing callback consumes the busy/timeout sequence;
/// exhaustion reports a terminal outcome rather than dropping queued work.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattRetrySpec {
    #[serde(deserialize_with = "bounded_list::<_, _, 32>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 32)))]
    incomplete_discovery_delays_millis: Vec<u32>,
    #[serde(deserialize_with = "bounded_list::<_, _, 32>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 32)))]
    missing_attribute_delays_millis: Vec<u32>,
    #[serde(deserialize_with = "bounded_list::<_, _, 32>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 32)))]
    busy_or_timeout_delays_millis: Vec<u32>,
    pub operation_timeout_millis: u32,
}

impl BleGattRetrySpec {
    pub fn new(
        incomplete_discovery_delays_millis: Vec<u32>,
        missing_attribute_delays_millis: Vec<u32>,
        busy_or_timeout_delays_millis: Vec<u32>,
        operation_timeout_millis: u32,
    ) -> Result<Self, BlePreparationError> {
        if incomplete_discovery_delays_millis.len() > 32
            || missing_attribute_delays_millis.len() > 32
            || busy_or_timeout_delays_millis.len() > 32
        {
            return Err(BlePreparationError::TooManyItems { limit: 32 });
        }
        Ok(Self {
            incomplete_discovery_delays_millis,
            missing_attribute_delays_millis,
            busy_or_timeout_delays_millis,
            operation_timeout_millis,
        })
    }

    pub fn incomplete_discovery_delays_millis(&self) -> &[u32] {
        &self.incomplete_discovery_delays_millis
    }
    pub fn missing_attribute_delays_millis(&self) -> &[u32] {
        &self.missing_attribute_delays_millis
    }
    pub fn busy_or_timeout_delays_millis(&self) -> &[u32] {
        &self.busy_or_timeout_delays_millis
    }
}

/// Discover the supplied attributes and apply subscriptions in order before
/// reporting GATT readiness. Core supplies every UUID, write mode and retry.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleCentralSpec {
    pub service_uuid: [u8; 16],
    pub requested_mtu: u16,
    #[serde(deserialize_with = "bounded_list::<_, _, 16>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 16)))]
    required_characteristics: Vec<[u8; 16]>,
    #[serde(deserialize_with = "bounded_list::<_, _, 16>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 16)))]
    subscriptions: Vec<BleSubscriptionSpec>,
    #[serde(deserialize_with = "bounded_list::<_, _, 16>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 16)))]
    write_modes: Vec<BleCharacteristicWriteSpec>,
    pub retry: BleGattRetrySpec,
}

impl BleCentralSpec {
    pub fn new(
        service_uuid: [u8; 16],
        requested_mtu: u16,
        required_characteristics: Vec<[u8; 16]>,
        subscriptions: Vec<BleSubscriptionSpec>,
        write_modes: Vec<BleCharacteristicWriteSpec>,
        retry: BleGattRetrySpec,
    ) -> Result<Self, BlePreparationError> {
        if required_characteristics.len() > 16 || subscriptions.len() > 16 || write_modes.len() > 16
        {
            return Err(BlePreparationError::TooManyItems { limit: 16 });
        }
        Ok(Self {
            service_uuid,
            requested_mtu,
            required_characteristics,
            subscriptions,
            write_modes,
            retry,
        })
    }

    pub fn required_characteristics(&self) -> &[[u8; 16]] {
        &self.required_characteristics
    }
    pub fn subscriptions(&self) -> &[BleSubscriptionSpec] {
        &self.subscriptions
    }
    pub fn write_modes(&self) -> &[BleCharacteristicWriteSpec] {
        &self.write_modes
    }
}
