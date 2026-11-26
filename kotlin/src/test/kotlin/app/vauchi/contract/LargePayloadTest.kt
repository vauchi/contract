// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Test
import java.security.MessageDigest

class LargePayloadTest {
    @Test
    fun imageSizedBytePayloadsEncodeWithinTheConstrainedHeap() {
        val bytes =
            object : AbstractList<UByte>() {
                override val size = 1_048_576

                override fun get(index: Int): UByte = (index and 255).toUByte()
            }

        val encoded = ContractJson.encodeEvent(Event.ImageReceived(bytes))
        val digest =
            MessageDigest
                .getInstance("SHA-256")
                .digest(encoded.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }

        assertEquals(3_743_772, encoded.length)
        assertEquals("91435f4a6b1162a89f360558cbb666276f7b40292b9c2077c35572d2c41d4598", digest)
    }
}
