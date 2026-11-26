// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use super::{BleAttributeValue, BleGattServiceSpec, BlePreparationError, bounded_list};
use serde::{Deserialize, Serialize};

/// Prepared UUIDs retain the width requested for the advertisement.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BleAdvertisedUuid {
    Uuid16([u8; 2]),
    Uuid32([u8; 4]),
    Uuid128([u8; 16]),
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BleAdvertisingMode {
    LowPower,
    Balanced,
    LowLatency,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BleAdvertisingTxPower {
    UltraLow,
    Low,
    Medium,
    High,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleAdvertisingParameters {
    pub mode: BleAdvertisingMode,
    pub tx_power: BleAdvertisingTxPower,
    pub connectable: bool,
    pub include_device_name: bool,
    pub timeout_millis: u32,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleAdvertisementSpec {
    #[serde(deserialize_with = "bounded_list::<_, _, 32>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 32)))]
    service_uuids: Vec<BleAdvertisedUuid>,
    pub parameters: BleAdvertisingParameters,
}

impl BleAdvertisementSpec {
    pub fn new(
        service_uuids: Vec<BleAdvertisedUuid>,
        parameters: BleAdvertisingParameters,
    ) -> Result<Self, BlePreparationError> {
        if service_uuids.len() > 32 {
            return Err(BlePreparationError::TooManyItems { limit: 32 });
        }
        Ok(Self {
            service_uuids,
            parameters,
        })
    }

    pub fn service_uuids(&self) -> &[BleAdvertisedUuid] {
        &self.service_uuids
    }
}

/// A descriptor write matches when its bytes start with `value_prefix`.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleDescriptorWriteCondition {
    pub characteristic_uuid: [u8; 16],
    pub descriptor_uuid: [u8; 16],
    pub value_prefix: BleAttributeValue,
}

/// Register the service before advertising so early peers can discover it.
/// All readiness conditions must be observed on the same link before it is ready.
#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlePeripheralSpec {
    pub advertisement: BleAdvertisementSpec,
    pub service: BleGattServiceSpec,
    #[serde(deserialize_with = "bounded_list::<_, _, 16>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 16)))]
    readiness_conditions: Vec<BleDescriptorWriteCondition>,
}

impl BlePeripheralSpec {
    pub fn new(
        advertisement: BleAdvertisementSpec,
        service: BleGattServiceSpec,
        readiness_conditions: Vec<BleDescriptorWriteCondition>,
    ) -> Result<Self, BlePreparationError> {
        if readiness_conditions.len() > 16 {
            return Err(BlePreparationError::TooManyItems { limit: 16 });
        }
        Ok(Self {
            advertisement,
            service,
            readiness_conditions,
        })
    }

    pub fn readiness_conditions(&self) -> &[BleDescriptorWriteCondition] {
        &self.readiness_conditions
    }
}
