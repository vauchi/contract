// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive

internal object Rd {
    private fun primitive(
        v: WireValue,
        string: Boolean,
    ): JsonPrimitive {
        val p = v.json as? JsonPrimitive ?: refused()
        if (p == JsonNull || p.isString != string) refused()
        return p
    }

    fun validString(value: String): String {
        var index = 0
        while (index < value.length) {
            val c = value[index++]
            if (c.isHighSurrogate()) {
                if (index >= value.length || !value[index++].isLowSurrogate()) refused()
            } else if (c.isLowSurrogate()) {
                refused()
            }
        }
        return value
    }

    fun string(
        v: WireValue,
        minimum: Int = 0,
        maximum: Int = -1,
    ): String {
        val text = validString(primitive(v, true).content)
        val size = text.toByteArray(Charsets.UTF_8).size
        if (size < minimum || (maximum >= 0 && size > maximum)) refused()
        return text
    }

    fun noControls(value: String): String {
        if (value.any { Character.isISOControl(it) }) refused()
        return value
    }

    fun identifier(value: String): String {
        val size = value.toByteArray(Charsets.UTF_8).size
        if (size !in 1..128) refused()
        return noControls(value)
    }

    fun bool(v: WireValue): Boolean =
        when (primitive(v, false).content) {
            "true" -> true
            "false" -> false
            else -> refused()
        }

    private fun integer(
        v: WireValue,
        unsigned: Boolean,
    ): String {
        val text = primitive(v, false).content
        val digits = if (!unsigned && text.startsWith('-')) text.substring(1) else text
        // serde_json treats negative zero as a float, including the -0 spelling.
        if (text == "-0") refused()
        if (digits.isEmpty() || digits.any { it !in '0'..'9' } || (digits.length > 1 && digits[0] == '0')) refused()
        return text
    }

    fun u64(v: WireValue): ULong = integer(v, true).toULongOrNull() ?: refused()

    fun u32(v: WireValue): UInt = u64(v).also { if (it > UInt.MAX_VALUE.toULong()) refused() }.toUInt()

    fun u16(v: WireValue): UShort = u64(v).also { if (it > UShort.MAX_VALUE.toULong()) refused() }.toUShort()

    fun u8(v: WireValue): UByte = u64(v).also { if (it > UByte.MAX_VALUE.toULong()) refused() }.toUByte()

    fun i32(v: WireValue): Int = integer(v, false).toIntOrNull() ?: refused()

    fun i16(v: WireValue): Short = integer(v, false).toShortOrNull() ?: refused()

    fun f64(v: WireValue): Double = primitive(v, false).content.toDoubleOrNull()?.takeIf { it.isFinite() } ?: refused()

    fun f32(v: WireValue): Float = primitive(v, false).content.toFloatOrNull()?.takeIf { it.isFinite() } ?: refused()

    fun <T> list(
        v: WireValue,
        minimum: Int,
        maximum: Int,
        read: (WireValue) -> T,
    ): List<T> {
        val items = v.json as? JsonArray ?: refused()
        if (items.size < minimum || (maximum >= 0 && items.size > maximum)) refused()
        return items.mapIndexed { index, item -> read(v.child(index.toString(), item)) }
    }

    fun qrPlacement(value: QrPlacement): QrPlacement {
        val size = value.size.toInt()
        val room = 1000 - size
        if (size < 500 || room < 0 || value.x.toInt() > room || value.y.toInt() > room) refused()
        return value
    }
}
