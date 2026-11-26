// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

internal object Wr {
    fun number(value: String): JsonElement {
        if (value in setOf("NaN", "Infinity", "-Infinity")) refused()
        return Json.parseToJsonElement(value)
    }

    fun obj(vararg fields: Pair<String, JsonElement?>): JsonObject =
        JsonObject(fields.mapNotNull { (name, value) -> value?.let { name to it } }.toMap())
}
