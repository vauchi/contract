// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.SerializationException

/** A refused wire message. Diagnostics must never contain payload values. */
class ContractJsonException internal constructor(
    message: String,
) : IllegalArgumentException(message)

/** Strict contract JSON. Callers bound message size before decoding. */
object ContractJson {
    fun decodeCommand(json: String): Command = decode(json, ::readCommand)

    fun encodeCommand(value: Command): String = encode(value, ::writeCommand)

    fun decodeEvent(json: String): Event = decode(json, ::readEvent)

    fun encodeEvent(value: Event): String = encode(value, ::writeEvent)

    fun decodeNode(json: String): PresentationNode = decode(json, ::readPresentationNode)

    fun encodeNode(value: PresentationNode): String = encode(value, ::writePresentationNode)

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
        value: T,
        write: (WireOutput, T) -> Unit,
    ): String {
        val output = WireOutput()
        write(output, value)
        return output.finish()
    }
}
