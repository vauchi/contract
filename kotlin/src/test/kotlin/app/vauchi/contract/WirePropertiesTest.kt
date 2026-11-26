// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import io.kotest.property.Arb
import io.kotest.property.arbitrary.byte
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class WirePropertiesTest {
    @Test
    fun revisionsAndBytePayloadsRetainTheirFullRange() =
        runBlocking<Unit> {
            checkAll(1000, Arb.long(), Arb.list(Arb.byte(), 0..256)) { revision, bytes ->
                val command = Command.SetStatusItem(surfaceId = "surface", revision = revision.toULong(), item = null)
                val observation =
                    Event.NfcDataReceived(
                        data = bytes.map { it.toUByte() },
                    )

                assertEquals(command, ContractJson.decodeCommand(ContractJson.encodeCommand(command)))
                assertEquals(observation, ContractJson.decodeEvent(ContractJson.encodeEvent(observation)))
            }
        }

    @Test
    fun arbitraryTextRoundTripsWithoutChangingEscapes() =
        runBlocking<Unit> {
            val edges = Arb.element("", "\"\\\u0000\n\r\t", "é", "😀", "\u2028\u2029")
            checkAll(1000, Arb.string(0..512), edges) { generated, edge ->
                val text = edge + generated + edge
                val event = Event.QrScanned(data = text)

                assertEquals(event, ContractJson.decodeEvent(ContractJson.encodeEvent(event)))
            }
        }

    @Test
    fun negativeUnsignedValuesAreAlwaysRefused() =
        runBlocking<Unit> {
            checkAll(1000, Arb.long(1..Long.MAX_VALUE)) { magnitude ->
                val message = """{"SetStatusItem":{"surface_id":"s","revision":-$magnitude,"item":null}}"""

                assertThrows(ContractJsonException::class.java) { ContractJson.decodeCommand(message) }
            }
        }
}
