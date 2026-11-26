// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ConstructedValueTest {
    @Test
    fun constructedEventsRetainTheIdentifierAndFiniteNumberGuards() {
        val invalid =
            listOf(
                Event.ActionActivated(interactionId = "", surfaceId = "surface"),
                Event.ActionActivated(interactionId = "private\u0001", surfaceId = "surface"),
                Event.ValueChanged(bindingId = "binding", surfaceId = "surface", value = InputValue.Number(Double.NaN)),
                Event.ValueChanged(bindingId = "binding", surfaceId = "surface", value = InputValue.Number(Double.POSITIVE_INFINITY)),
            )

        invalid.forEach { event ->
            val error = assertThrows(ContractJsonException::class.java) { ContractJson.encodeEvent(event) }
            assertEquals("invalid contract message", error.message)
            assertNull(error.cause)
        }
    }

    @Test
    fun constructedQrPlacementStillHasToFitItsSquare() {
        val valid =
            ContractJson.decodeNode(
                """{"Qr":{"id":"qr","payloads":["value"],"purpose":"display","accessibility":{"label":"Code"}}}""",
            ) as PresentationNode.Qr
        val invalid = valid.copy(placement = QrPlacement(size = 800u, x = 500u, y = 0u))

        val error = assertThrows(ContractJsonException::class.java) { ContractJson.encodeNode(invalid) }

        assertEquals("invalid contract message", error.message)
        assertNull(error.cause)
    }

    @Test
    fun constructedUuidBytesStillHaveTheirFixedWidth() {
        val event =
            Event.BleAdvertisementObserved(
                BleAdvertisementObservation("opaque", -40, listOf(BleServiceUuid.Uuid16(listOf(1u)))),
            )

        val error = assertThrows(ContractJsonException::class.java) { ContractJson.encodeEvent(event) }

        assertEquals("invalid contract message", error.message)
        assertNull(error.cause)
    }
}
