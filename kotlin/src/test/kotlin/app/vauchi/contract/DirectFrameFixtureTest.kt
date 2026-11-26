// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File

class DirectFrameFixtureTest {
    private val path = "/app/vauchi/contract/direct_frames_v1.json"
    private val resource =
        javaClass.getResourceAsStream(path)?.bufferedReader()?.use { it.readText() }
            ?: error("missing direct-frame fixture")
    private val fixture = Json.parseToJsonElement(resource).jsonObject

    private fun bytes(value: JsonElement): ByteArray = value.jsonArray.map { it.jsonPrimitive.int.toByte() }.toByteArray()

    @Test
    fun packagedVectorsAreTheExactSharedVersionedFixture() {
        val expected = File(System.getProperty("vauchi.contractCheckout"), "fixtures/direct_frames_v1.json").readText()
        assertEquals(expected, resource)
        assertEquals(1, fixture.getValue("schema_version").jsonPrimitive.int)
        assertEquals(3, fixture.getValue("valid").jsonArray.size)
        assertEquals(7, fixture.getValue("invalid").jsonArray.size)
    }

    @Test
    fun validSharedFramesEncodeAndDecodeWithoutChangingBytes() {
        for (entry in fixture.getValue("valid").jsonArray) {
            val example = entry.jsonObject
            val payload = bytes(example.getValue("payload"))
            val frame = bytes(example.getValue("frame"))
            val output = ByteArrayOutputStream()
            DirectFrame.write(output, payload)
            assertArrayEquals(frame, output.toByteArray())
            val input = ByteArrayInputStream(frame)
            assertArrayEquals(payload, DirectFrame.read(input))
            assertEquals(0, input.available())
        }
    }

    @Test
    fun invalidSharedFramesFailAtTheSameBoundaryAsRust() {
        for (entry in fixture.getValue("invalid").jsonArray) {
            val example = entry.jsonObject
            val frame = bytes(example.getValue("frame"))
            val input = ByteArrayInputStream(frame)
            val error = assertThrows(DirectFrameException::class.java) { DirectFrame.read(input) }
            assertEquals(example.getValue("error").jsonPrimitive.content, error.error.name)
            assertEquals(example.getValue("consumed").jsonPrimitive.int, frame.size - input.available())
        }
    }
}
