// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

internal fun refused(): Nothing = throw ContractJsonException("invalid contract message")

internal class WireValue(
    val json: JsonElement,
    private val duplicates: Map<List<String>, Set<String>> = emptyMap(),
    private val path: List<String> = emptyList(),
) {
    fun child(
        name: String,
        value: JsonElement,
    ) = WireValue(value, duplicates, path + name)

    fun member(name: String): WireValue? = (json as? JsonObject)?.get(name)?.let { child(name, it) }

    fun required(name: String): WireValue = member(name) ?: refused()

    fun objectFields(
        known: Set<String>,
        closed: Boolean = false,
    ) {
        val obj = json as? JsonObject ?: refused()
        if (duplicates[path].orEmpty().any { it in known } || (closed && obj.keys.any { it !in known })) refused()
    }

    fun variant(): Pair<String, WireValue> {
        val obj = json as? JsonObject ?: refused()
        if (obj.size != 1 || duplicates[path].orEmpty().isNotEmpty()) refused()
        val entry = obj.entries.single()
        return entry.key to child(entry.key, entry.value)
    }
}

/** JsonObject collapses duplicate keys; record them before the JSON parser does. */
internal class WireInput(
    private val text: String,
) {
    private var offset = 0
    private val duplicates = mutableMapOf<List<String>, Set<String>>()

    fun parse(): WireValue {
        value(emptyList(), 0)
        whitespace()
        if (offset != text.length) refused()
        return WireValue(Json.parseToJsonElement(text), duplicates)
    }

    private fun whitespace() {
        while (offset < text.length && text[offset] in " \t\r\n") offset++
    }

    private fun take(char: Char) {
        whitespace()
        if (offset >= text.length || text[offset++] != char) refused()
    }

    private fun peek(): Char {
        whitespace()
        return text.getOrNull(offset) ?: refused()
    }

    private fun string(): String {
        whitespace()
        val start = offset
        take('"')
        while (offset < text.length) {
            when (text[offset++]) {
                '\\' -> {
                    if (offset >= text.length) refused()
                    offset++
                }

                '"' -> {
                    val decoded = (Json.parseToJsonElement(text.substring(start, offset)) as? JsonPrimitive) ?: refused()
                    return Rd.validString(decoded.content)
                }
            }
        }
        refused()
    }

    private fun value(
        path: List<String>,
        depth: Int,
    ) {
        when (peek()) {
            '{' -> {
                if (depth >= 127) refused()
                take('{')
                val seen = mutableSetOf<String>()
                if (peek() != '}') {
                    while (true) {
                        val name = string()
                        if (!seen.add(name)) duplicates[path] = duplicates[path].orEmpty() + name
                        take(':')
                        value(path + name, depth + 1)
                        if (peek() == '}') break
                        take(',')
                    }
                }
                take('}')
            }

            '[' -> {
                if (depth >= 127) refused()
                take('[')
                var index = 0
                if (peek() != ']') {
                    while (true) {
                        value(path + (index++).toString(), depth + 1)
                        if (peek() == ']') break
                        take(',')
                    }
                }
                take(']')
            }

            '"' -> {
                string()
            }

            else -> {
                val start = offset
                while (offset < text.length && text[offset] !in ",]} \t\r\n") offset++
                if (offset == start) refused()
            }
        }
    }
}
