// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Test

class ContractBytesTest {
    @Test
    fun nativeBytesBecomeAnOwnedUnsignedPayloadWithRedactedDiagnostics() {
        val source = byteArrayOf(0, 127, -128, -1)
        val payload = ContractBytes.copyOf(source)
        source.fill(9)

        assertEquals(listOf<UByte>(0u, 127u, 128u, 255u), payload)
        assertEquals("ContractBytes", payload.toString())
        assertEquals("""{"NfcDataReceived":{"data":[0,127,128,255]}}""", ContractJson.encodeEvent(Event.NfcDataReceived(payload)))
    }
}
