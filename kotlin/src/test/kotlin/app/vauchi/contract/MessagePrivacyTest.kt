// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class MessagePrivacyTest {
    @Test
    fun commandAndEventDiagnosticsDoNotExposePayloads() {
        val secret = "s3cret-card-and-key-material"
        val command =
            Command.BleWriteCharacteristic(
                data = listOf(1u.toUByte(), 255u.toUByte()),
                deviceId = secret,
                direction = BleLinkDirection.Outbound,
                uuid = secret,
            )
        val event = Event.QrScanned(data = secret)

        assertEquals("BleWriteCharacteristic", command.toString())
        assertEquals("QrScanned", event.toString())
        assertFalse(command.toString().contains(secret))
        assertFalse(event.toString().contains(secret))
    }

    @Test
    fun supportingValueDiagnosticsDoNotExposeUserText() {
        val value = ToastSpec(message = "s3cret-contact-card-content")

        assertEquals("ToastSpec", value.toString())
        assertFalse(value.toString().contains("s3cret"))
    }
}
