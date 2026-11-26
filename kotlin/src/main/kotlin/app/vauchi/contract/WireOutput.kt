// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

internal class WireOutput(
    private val text: Appendable = StringBuilder(),
) {
    private class Frame(
        val objectValue: Boolean,
        var first: Boolean = true,
        var expectsValue: Boolean = false,
    )

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
        quoted(Rd.validString(name))
        text.append(':')
    }

    fun string(
        value: String,
        minimum: Int = 0,
        maximum: Int = -1,
    ) {
        Rd.validString(value)
        if (minimum > 0 || maximum >= 0) {
            val size = value.sumOf { utf8Width(it).toLong() }
            if (size < minimum || (maximum >= 0 && size > maximum)) refused()
        }
        beforeValue()
        quoted(value)
    }

    private fun quoted(value: String) {
        text.append('"')
        for (character in value) {
            when (character) {
                '"' -> {
                    text.append("\\\"")
                }

                '\\' -> {
                    text.append("\\\\")
                }

                '\b' -> {
                    text.append("\\b")
                }

                '\u000C' -> {
                    text.append("\\f")
                }

                '\n' -> {
                    text.append("\\n")
                }

                '\r' -> {
                    text.append("\\r")
                }

                '\t' -> {
                    text.append("\\t")
                }

                in '\u0000'..'\u001F' -> {
                    text.append("\\u00")
                    text.append("0123456789abcdef"[character.code shr 4])
                    text.append("0123456789abcdef"[character.code and 15])
                }

                else -> {
                    text.append(character)
                }
            }
        }
        text.append('"')
    }

    fun number(value: String) {
        if (value == "NaN" || value == "Infinity" || value == "-Infinity") refused()
        beforeValue()
        text.append(value)
    }

    fun bool(value: Boolean) {
        beforeValue()
        text.append(if (value) "true" else "false")
    }

    fun nullValue() {
        beforeValue()
        text.append("null")
    }

    fun complete() {
        if (!root || frames.isNotEmpty()) refused()
    }

    fun finish(): String {
        complete()
        return text.toString()
    }
}

internal fun utf8Width(character: Char): Int =
    when {
        character.code < 0x80 -> 1
        character.code < 0x800 -> 2
        character.isHighSurrogate() -> 4
        character.isLowSurrogate() -> 0
        else -> 3
    }
