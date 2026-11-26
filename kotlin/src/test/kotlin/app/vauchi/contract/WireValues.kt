// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import java.math.BigDecimal

internal object WireValues {
    fun difference(
        expected: JsonElement,
        actual: JsonElement,
        path: String = "\$",
    ): String? {
        if (expected is JsonObject && actual is JsonObject) {
            for ((key, value) in expected) {
                val other = actual[key]
                if (other == null) {
                    if (value == JsonNull) continue
                    return "$path.$key is missing"
                }
                difference(value, other, "$path.$key")?.let { return it }
            }
            return (actual.keys - expected.keys).firstOrNull()?.let { "$path.$it is extra" }
        }
        if (expected is JsonArray && actual is JsonArray) {
            if (expected.size != actual.size) return "$path array length changed"
            expected.indices.forEach { index ->
                difference(expected[index], actual[index], "$path[$index]")?.let { return it }
            }
            return null
        }
        if (expected == JsonNull || actual == JsonNull) {
            return if (expected == actual) null else "$path nullability changed"
        }
        if (expected !is JsonPrimitive || actual !is JsonPrimitive) return "$path kind changed"
        if (expected.isString || actual.isString) {
            return if (expected.isString && actual.isString && expected.content == actual.content) null else "$path text changed"
        }
        if (expected.booleanOrNull != null || actual.booleanOrNull != null) {
            return if (expected.booleanOrNull == actual.booleanOrNull) null else "$path boolean changed"
        }
        val left = BigDecimal(expected.content)
        val right = BigDecimal(actual.content)
        if (left.compareTo(right) == 0) return null
        // The oracle widens f32 to f64; a wire writer uses the shorter f32
        // spelling. Keep integer comparisons decimal so u64 cannot round.
        val float = expected.content.toFloatOrNull()
        if (float != null && float.isFinite() &&
            left.compareTo(BigDecimal(float.toDouble().toString())) == 0 &&
            right.compareTo(BigDecimal(float.toString())) == 0
        ) {
            return null
        }
        return "$path number changed"
    }
}
