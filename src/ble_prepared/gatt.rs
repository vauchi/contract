// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use super::{BleAttributeValue, BlePreparationError, bounded_list};
use serde::{Deserialize, Serialize};

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattProperties {
    pub read: bool,
    pub write: bool,
    pub write_without_response: bool,
    pub notify: bool,
    pub indicate: bool,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattPermissions {
    pub read: bool,
    pub write: bool,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattDescriptorSpec {
    pub uuid: [u8; 16],
    pub permissions: BleGattPermissions,
    pub value: BleAttributeValue,
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattCharacteristicSpec {
    pub uuid: [u8; 16],
    pub properties: BleGattProperties,
    pub permissions: BleGattPermissions,
    pub initial_value: BleAttributeValue,
    #[serde(deserialize_with = "bounded_list::<_, _, 4>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 4)))]
    descriptors: Vec<BleGattDescriptorSpec>,
}

impl BleGattCharacteristicSpec {
    pub fn new(
        uuid: [u8; 16],
        properties: BleGattProperties,
        permissions: BleGattPermissions,
        initial_value: BleAttributeValue,
        descriptors: Vec<BleGattDescriptorSpec>,
    ) -> Result<Self, BlePreparationError> {
        if descriptors.len() > 4 {
            return Err(BlePreparationError::TooManyItems { limit: 4 });
        }
        Ok(Self {
            uuid,
            properties,
            permissions,
            initial_value,
            descriptors,
        })
    }

    pub fn descriptors(&self) -> &[BleGattDescriptorSpec] {
        &self.descriptors
    }
}

#[cfg_attr(feature = "schema-gen", derive(schemars::JsonSchema))]
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BleGattServiceSpec {
    pub uuid: [u8; 16],
    pub primary: bool,
    #[serde(deserialize_with = "bounded_list::<_, _, 16>")]
    #[cfg_attr(feature = "schema-gen", schemars(length(max = 16)))]
    characteristics: Vec<BleGattCharacteristicSpec>,
}

impl BleGattServiceSpec {
    pub fn new(
        uuid: [u8; 16],
        primary: bool,
        characteristics: Vec<BleGattCharacteristicSpec>,
    ) -> Result<Self, BlePreparationError> {
        if characteristics.len() > 16 {
            return Err(BlePreparationError::TooManyItems { limit: 16 });
        }
        Ok(Self {
            uuid,
            primary,
            characteristics,
        })
    }

    pub fn characteristics(&self) -> &[BleGattCharacteristicSpec] {
        &self.characteristics
    }
}
