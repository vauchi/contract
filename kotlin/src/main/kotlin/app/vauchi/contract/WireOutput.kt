// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.JsonPrimitive

internal class WireOutput {
    private class Frame(
        val objectValue: Boolean,
        var first: Boolean = true,
        var expectsValue: Boolean = false,
    )

    private val text = StringBuilder()
    private val frames = mutableListOf<Frame>()
    private var root = false

    private fun beforeValue() {
        val frame = frames.lastOrNull()
        if (frame == null) {
            if (root) refused()
            root = true
        } else if (frame.objectValue) {
            if (!frame.expectsValue) refused()
            frame.expectsValue = false
        } else {
            if (!frame.first) text.append(',')
            frame.first = false
        }
    }

    private fun begin(objectValue: Boolean) {
        if (frames.size >= 127) refused()
        beforeValue()
        text.append(if (objectValue) '{' else '[')
        frames.add(Frame(objectValue))
    }

    fun beginObject() = begin(true)

    fun beginArray(
        size: Int,
        minimum: Int,
        maximum: Int,
    ) {
        if (size < minimum || (maximum >= 0 && size > maximum)) refused()
        begin(false)
    }

    private fun end(objectValue: Boolean) {
        val frame = frames.lastOrNull() ?: refused()
        if (frame.objectValue != objectValue || frame.expectsValue) refused()
        frames.removeAt(frames.lastIndex)
        text.append(if (objectValue) '}' else ']')
    }

    fun endObject() = end(true)

    fun endArray() = end(false)

    fun name(name: String) {
        val frame = frames.lastOrNull() ?: refused()
        if (!frame.objectValue || frame.expectsValue) refused()
        if (!frame.first) text.append(',')
        frame.first = false
        frame.expectsValue = true
        text.append(JsonPrimitive(name).toString()).append(':')
    }

    fun string(
        value: String,
        minimum: Int = 0,
        maximum: Int = -1,
    ) {
        Rd.validString(value)
        if (minimum > 0 || maximum >= 0) {
            val size = value.toByteArray(Charsets.UTF_8).size
            if (size < minimum || (maximum >= 0 && size > maximum)) refused()
        }
        beforeValue()
        text.append(JsonPrimitive(value).toString())
    }

    fun number(value: String) {
        if (value in setOf("NaN", "Infinity", "-Infinity")) refused()
        beforeValue()
        text.append(value)
    }

    fun bool(value: Boolean) {
        beforeValue()
        text.append(value)
    }

    fun nullValue() {
        beforeValue()
        text.append("null")
    }

    fun finish(): String {
        if (!root || frames.isNotEmpty()) refused()
        return text.toString()
    }
}
