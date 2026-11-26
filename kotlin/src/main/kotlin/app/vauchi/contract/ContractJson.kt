// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonElement

/** A refused wire message. Diagnostics must never contain payload values. */
class ContractJsonException internal constructor(
    message: String,
) : IllegalArgumentException(message)

object ContractJson {
    fun decodeCommand(json: String): Command = decode(json, ::readCommand)

    fun encodeCommand(value: Command): String = encode(writeCommand(value), ::readCommand)

    fun decodeEvent(json: String): Event = decode(json, ::readEvent)

    fun encodeEvent(value: Event): String = encode(writeEvent(value), ::readEvent)

    fun decodeNode(json: String): PresentationNode = decode(json, ::readPresentationNode)

    fun encodeNode(value: PresentationNode): String = encode(writePresentationNode(value), ::readPresentationNode)

    private fun <T> decode(
        json: String,
        read: (WireValue) -> T,
    ): T =
        try {
            read(WireInput(json).parse())
        } catch (_: SerializationException) {
            refused()
        } catch (_: IllegalStateException) {
            refused()
        }

    private fun <T> encode(
        json: JsonElement,
        read: (WireValue) -> T,
    ): String {
        // Validate constructed values too: public constructors cannot enforce
        // identifier, finite-number and cross-field schema constraints.
        val text = json.toString()
        decode(text, read)
        return text
    }
}
