// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

/** A refused wire message. Diagnostics must never contain payload values. */
class ContractJsonException internal constructor(
    message: String,
) : IllegalArgumentException(message)

object ContractJson {
    fun decodeCommand(json: String): Command = throw ContractJsonException("codec unavailable")

    fun encodeCommand(value: Command): String = throw ContractJsonException("codec unavailable")

    fun decodeEvent(json: String): Event = throw ContractJsonException("codec unavailable")

    fun encodeEvent(value: Event): String = throw ContractJsonException("codec unavailable")

    fun decodeNode(json: String): PresentationNode = throw ContractJsonException("codec unavailable")

    fun encodeNode(value: PresentationNode): String = throw ContractJsonException("codec unavailable")
}
