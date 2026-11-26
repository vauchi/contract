// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import io.kotest.property.Arb
import io.kotest.property.arbitrary.byte
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

class DirectFrameTest {
    private class Output : ByteArrayOutputStream() {
        var flushes = 0

        override fun flush() {
            flushes++
        }
    }

    private fun frame(
        length: Long,
        payload: ByteArray = byteArrayOf(),
    ): ByteArray =
        byteArrayOf(86, 88, 67, 72, 1) +
            byteArrayOf(
                (length shr 24).toByte(),
                (length shr 16).toByte(),
                (length shr 8).toByte(),
                length.toByte(),
            ) + payload

    @Test
    fun writesCanonicalMagicVersionBigEndianLengthPayloadAndFlush() {
        val output = Output()
        DirectFrame.write(output, byteArrayOf(-86, -69, -52))
        assertArrayEquals(byteArrayOf(86, 88, 67, 72, 1, 0, 0, 0, 3, -86, -69, -52), output.toByteArray())
        assertEquals(1, output.flushes)
        val larger = Output()
        DirectFrame.write(larger, ByteArray(0x0102))
        assertArrayEquals(byteArrayOf(0, 0, 1, 2), larger.toByteArray().copyOfRange(5, 9))
    }

    @Test
    fun inclusivePayloadBoundAndFollowingBytesArePreserved() {
        assertEquals(65_536, DirectFrame.MAX_PAYLOAD)
        for (size in listOf(1, 300, DirectFrame.MAX_PAYLOAD)) {
            val payload = ByteArray(size) { it.toByte() }
            val input = ByteArrayInputStream(frame(size.toLong(), payload) + byteArrayOf(99))
            assertArrayEquals(payload, DirectFrame.read(input))
            assertEquals(99, input.read())
        }
    }

    @Test
    fun invalidLocalLengthsWriteAndFlushNothing() {
        for ((payload, reason) in listOf(
            byteArrayOf() to DirectFrameError.EmptyPayload,
            ByteArray(DirectFrame.MAX_PAYLOAD + 1) to DirectFrameError.PayloadTooLarge,
        )) {
            val output = Output()
            val error = assertThrows(DirectFrameException::class.java) { DirectFrame.write(output, payload) }
            assertEquals(reason, error.error)
            assertEquals(0, output.size())
            assertEquals(0, output.flushes)
        }
    }

    @Test
    fun invalidMagicAndVersionStopAtTheirOwnHeaderField() {
        val wrongMagic = byteArrayOf(0, 88, 67, 72, 1, 0, 0, 0, 1, 7)
        val input = ByteArrayInputStream(wrongMagic)
        val magic = assertThrows(DirectFrameException::class.java) { DirectFrame.read(input) }
        assertEquals(DirectFrameError.InvalidMagic, magic.error)
        assertEquals(wrongMagic.size - 4, input.available())
        for (version in listOf(0, 2, 255)) {
            val bytes = frame(1, byteArrayOf(7))
            bytes[4] = version.toByte()
            val peer = ByteArrayInputStream(bytes)
            val error = assertThrows(DirectFrameException::class.java) { DirectFrame.read(peer) }
            assertEquals(DirectFrameError.UnsupportedVersion, error.error)
            assertEquals("unsupported frame version", error.message)
            assertEquals(bytes.size - 5, peer.available())
        }
    }

    @Test
    fun invalidUnsignedLengthsAreRejectedBeforeReadingPayload() {
        for (length in listOf(0L, 65_537L, 0x7FFF_FFFFL, 0x8000_0000L, 0xFFFF_FFFFL)) {
            val input = ByteArrayInputStream(frame(length, byteArrayOf(7, 8, 9)))
            val error = assertThrows(DirectFrameException::class.java) { DirectFrame.read(input) }
            val expected = if (length == 0L) DirectFrameError.EmptyPayload else DirectFrameError.PayloadTooLarge
            assertEquals(expected, error.error)
            assertEquals(3, input.available())
        }
    }

    @Test
    fun truncationAtAnyHeaderOrPayloadByteIsAnExplicitRefusal() {
        val bytes = frame(3, byteArrayOf(1, 2, 3))
        for (kept in bytes.indices) {
            val error =
                assertThrows(DirectFrameException::class.java) {
                    DirectFrame.read(ByteArrayInputStream(bytes.copyOf(kept)))
                }
            assertEquals(DirectFrameError.Truncated, error.error)
            assertEquals("frame ended early", error.message)
        }
    }

    @Test
    fun fragmentedStreamsAndZeroBulkReadsStillDeliverExactlyOneFrame() {
        val bytes = ByteArrayInputStream(frame(3, byteArrayOf(4, 5, 6)) + byteArrayOf(99))
        val input =
            object : InputStream() {
                private var zero = true

                override fun read(): Int = bytes.read()

                override fun read(
                    buffer: ByteArray,
                    offset: Int,
                    length: Int,
                ): Int {
                    zero = !zero
                    return if (zero) 0 else bytes.read(buffer, offset, minOf(1, length))
                }
            }
        assertArrayEquals(byteArrayOf(4, 5, 6), DirectFrame.read(input))
        assertEquals(99, input.read())
    }

    @Test
    fun nativeReadWriteAndFlushFailuresPropagateWithoutReplacingThem() {
        val native = IOException("native link failure")
        val readFailure =
            object : InputStream() {
                override fun read(): Int = throw native
            }
        assertSame(native, assertThrows(IOException::class.java) { DirectFrame.read(readFailure) })
        val writeFailure =
            object : OutputStream() {
                override fun write(value: Int): Unit = throw native
            }
        assertSame(native, assertThrows(IOException::class.java) { DirectFrame.write(writeFailure, byteArrayOf(1)) })
        val flushFailure =
            object : ByteArrayOutputStream() {
                override fun flush(): Unit = throw native
            }
        assertSame(native, assertThrows(IOException::class.java) { DirectFrame.write(flushFailure, byteArrayOf(1)) })
        assertArrayEquals(frame(1, byteArrayOf(1)), flushFailure.toByteArray())
    }

    @Test
    fun exchangeHonorsTheSuppliedRoleAndDoesNotCloseHostOwnedStreams() {
        for (initiator in listOf(true, false)) {
            val steps = mutableListOf<String>()
            val input =
                object : ByteArrayInputStream(frame(2, byteArrayOf(2, 2))) {
                    override fun read(
                        buffer: ByteArray,
                        offset: Int,
                        length: Int,
                    ): Int {
                        steps.add("read")
                        return super.read(buffer, offset, length)
                    }

                    override fun close() {
                        steps.add("closed")
                    }
                }
            val output =
                object : ByteArrayOutputStream() {
                    override fun write(
                        buffer: ByteArray,
                        offset: Int,
                        length: Int,
                    ) {
                        steps.add("write")
                        super.write(buffer, offset, length)
                    }

                    override fun flush() {
                        steps.add("flush")
                    }

                    override fun close() {
                        steps.add("closed")
                    }
                }
            val received = DirectFrame.exchange(input, output, byteArrayOf(1), initiator)
            assertArrayEquals(byteArrayOf(2, 2), received)
            assertArrayEquals(frame(1, byteArrayOf(1)), output.toByteArray())
            assertEquals(
                if (initiator) listOf("write", "flush", "read") else listOf("read", "write", "flush"),
                steps.distinct(),
            )
        }
    }

    @Test
    fun responderRefusesThePeerBeforeWritingItsOwnFrame() {
        val output = Output()
        val error =
            assertThrows(DirectFrameException::class.java) {
                DirectFrame.exchange(ByteArrayInputStream(frame(0)), output, byteArrayOf(1), false)
            }
        assertEquals(DirectFrameError.EmptyPayload, error.error)
        assertEquals(0, output.size())
        assertEquals(0, output.flushes)
    }

    @Test
    fun arbitraryPayloadsRoundTripThroughFragmentedLinks() =
        runBlocking<Unit> {
            checkAll(500, Arb.list(Arb.byte(), 1..2048), Arb.int(1..17)) { bytes, chunk ->
                val payload = bytes.toByteArray()
                val output = Output()
                DirectFrame.write(output, payload)
                assertArrayEquals(frame(payload.size.toLong(), payload), output.toByteArray())
                val input =
                    object : ByteArrayInputStream(output.toByteArray()) {
                        override fun read(
                            buffer: ByteArray,
                            offset: Int,
                            length: Int,
                        ): Int = super.read(buffer, offset, minOf(chunk, length))
                    }
                assertArrayEquals(payload, DirectFrame.read(input))
                assertEquals(0, input.available())
            }
        }
}
