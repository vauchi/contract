// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

use serde::de::{self, DeserializeSeed, SeqAccess, Visitor};
use serde::{Deserialize, Deserializer, Serialize};
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum BlePreparationError {
    #[error("BLE list exceeds {limit} items")]
    TooManyItems { limit: usize },
}

/// Opaque prepared GATT bytes, bounded independently of the native backend.
#[derive(Clone, PartialEq, Eq, Serialize)]
#[serde(transparent)]
pub struct BleAttributeValue(Vec<u8>);

impl BleAttributeValue {
    pub const MAX_BYTES: usize = 512;

    pub fn new(bytes: Vec<u8>) -> Result<Self, BlePreparationError> {
        if bytes.len() > Self::MAX_BYTES {
            return Err(BlePreparationError::TooManyItems {
                limit: Self::MAX_BYTES,
            });
        }
        Ok(Self(bytes))
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }
}

impl fmt::Debug for BleAttributeValue {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("BleAttributeValue")
            .field("len", &self.0.len())
            .finish()
    }
}

impl<'de> Deserialize<'de> for BleAttributeValue {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        bounded_list::<D, u8, 512>(deserializer).map(Self)
    }
}

#[cfg(feature = "schema-gen")]
impl schemars::JsonSchema for BleAttributeValue {
    fn schema_name() -> String {
        "BleAttributeValue".into()
    }

    fn is_referenceable() -> bool {
        false
    }

    fn json_schema(generator: &mut schemars::r#gen::SchemaGenerator) -> schemars::schema::Schema {
        let mut schema = <Vec<u8>>::json_schema(generator).into_object();
        schema.array().max_items = Some(512);
        schema.into()
    }
}

fn bounded_list<'de, D, T, const LIMIT: usize>(deserializer: D) -> Result<Vec<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    struct Bounded<T, const LIMIT: usize>(std::marker::PhantomData<T>);
    impl<'de, T: Deserialize<'de>, const LIMIT: usize> Visitor<'de> for Bounded<T, LIMIT> {
        type Value = Vec<T>;

        fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
            write!(formatter, "a BLE list of at most {LIMIT} items")
        }

        fn visit_seq<A: SeqAccess<'de>>(self, mut sequence: A) -> Result<Self::Value, A::Error> {
            let mut values = Vec::new();
            while values.len() < LIMIT {
                match sequence.next_element()? {
                    Some(value) => values.push(value),
                    None => return Ok(values),
                }
            }
            match sequence.next_element_seed(RejectExcess { limit: LIMIT })? {
                None => Ok(values),
                Some(()) => Err(de::Error::custom(BlePreparationError::TooManyItems {
                    limit: LIMIT,
                })),
            }
        }
    }
    deserializer.deserialize_seq(Bounded::<T, LIMIT>(std::marker::PhantomData))
}

struct RejectExcess {
    limit: usize,
}

impl<'de> DeserializeSeed<'de> for RejectExcess {
    type Value = ();

    fn deserialize<D: Deserializer<'de>>(self, _deserializer: D) -> Result<Self::Value, D::Error> {
        Err(de::Error::custom(BlePreparationError::TooManyItems {
            limit: self.limit,
        }))
    }
}
