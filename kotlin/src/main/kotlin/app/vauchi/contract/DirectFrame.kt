// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

enum class DirectFrameError {
    InvalidMagic,
    UnsupportedVersion,
    PayloadTooLarge,
    EmptyPayload,
    Truncated,
}

/** Frame refusals name only the rule; native stream failures propagate unchanged. */
class DirectFrameException internal constructor(
    val error: DirectFrameError,
) : IOException(
        when (error) {
            DirectFrameError.InvalidMagic -> "invalid frame magic"
            DirectFrameError.UnsupportedVersion -> "unsupported frame version"
            DirectFrameError.PayloadTooLarge -> "payload too large"
            DirectFrameError.EmptyPayload -> "empty payload"
            DirectFrameError.Truncated -> "frame ended early"
        },
    )

/** Shared direct-link framing; the host owns streams, deadlines and native teardown. */
object DirectFrame {
    const val MAX_PAYLOAD: Int = 65_536
    private val magic = byteArrayOf(86, 88, 67, 72)
    private const val VERSION = 1

    fun write(
        link: OutputStream,
        payload: ByteArray,
    ) {
        when {
            payload.isEmpty() -> throw DirectFrameException(DirectFrameError.EmptyPayload)
            payload.size > MAX_PAYLOAD -> throw DirectFrameException(DirectFrameError.PayloadTooLarge)
        }
        val length = payload.size
        link.write(magic)
        link.write(
            byteArrayOf(
                VERSION.toByte(),
                (length ushr 24).toByte(),
                (length ushr 16).toByte(),
                (length ushr 8).toByte(),
                length.toByte(),
            ),
        )
        link.write(payload)
        link.flush()
    }

    fun read(link: InputStream): ByteArray {
        val prefix = ByteArray(4)
        fill(link, prefix)
        if (!prefix.contentEquals(magic)) throw DirectFrameException(DirectFrameError.InvalidMagic)
        val revision = ByteArray(1)
        fill(link, revision)
        if (revision[0].toInt() != VERSION) throw DirectFrameException(DirectFrameError.UnsupportedVersion)
        val encodedLength = ByteArray(4)
        fill(link, encodedLength)
        var length = 0L
        for (byte in encodedLength) length = (length shl 8) or (byte.toLong() and 255)
        when {
            length == 0L -> throw DirectFrameException(DirectFrameError.EmptyPayload)
            length > MAX_PAYLOAD -> throw DirectFrameException(DirectFrameError.PayloadTooLarge)
        }
        return ByteArray(length.toInt()).also { fill(link, it) }
    }

    fun exchange(
        input: InputStream,
        output: OutputStream,
        ours: ByteArray,
        isInitiator: Boolean,
    ): ByteArray =
        if (isInitiator) {
            write(output, ours)
            read(input)
        } else {
            val theirs = read(input)
            write(output, ours)
            theirs
        }

    private fun fill(
        link: InputStream,
        buffer: ByteArray,
    ) {
        var offset = 0
        while (offset < buffer.size) {
            val count = link.read(buffer, offset, buffer.size - offset)
            if (count < 0) throw DirectFrameException(DirectFrameError.Truncated)
            if (count == 0) {
                val byte = link.read()
                if (byte < 0) throw DirectFrameException(DirectFrameError.Truncated)
                buffer[offset++] = byte.toByte()
            } else {
                offset += count
            }
        }
    }
}
