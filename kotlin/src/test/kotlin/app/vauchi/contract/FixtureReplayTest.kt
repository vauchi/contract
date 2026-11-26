// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File

class FixtureReplayTest {
    private val fixture =
        Json
            .parseToJsonElement(
                File(System.getProperty("vauchi.contractCheckout"), "fixtures/protocol_conformance_v1.json").readText(),
            ).jsonObject

    private fun entries(section: String) = fixture.getValue(section) as JsonArray

    private fun unchanged(
        expected: JsonElement,
        written: String,
    ) {
        assertNull(WireValues.difference(expected, Json.parseToJsonElement(written)))
    }

    @Test
    fun sharedFixtureSectionsAreNonemptyAndVersioned() {
        assertEquals("1", fixture.getValue("schema_version").jsonPrimitive.content)
        assertEquals(2, entries("commands").size)
        assertEquals(3, entries("events").size)
        assertEquals(1, entries("nodes").size)
        assertEquals(2, entries("invalid_events").size)
    }

    @Test
    fun everySharedCommandRetainsItsWireValues() {
        entries("commands").forEach { unchanged(it, ContractJson.encodeCommand(ContractJson.decodeCommand(it.toString()))) }
    }

    @Test
    fun everySharedEventRetainsItsWireValues() {
        entries("events").forEach { unchanged(it, ContractJson.encodeEvent(ContractJson.decodeEvent(it.toString()))) }
    }

    @Test
    fun everySharedNodeRetainsItsWireValues() {
        entries("nodes").forEach { unchanged(it, ContractJson.encodeNode(ContractJson.decodeNode(it.toString()))) }
    }

    @Test
    fun malformedSharedEventsAreRefused() {
        entries("invalid_events").forEach {
            assertThrows(ContractJsonException::class.java) { ContractJson.decodeEvent(it.toString()) }
        }
    }

    @Test
    fun theBleFixtureHasThePreparedTypedFields() {
        val command = ContractJson.decodeCommand(entries("commands").first().toString()) as Command.BleWriteCharacteristic

        assertEquals("opaque.peer", command.deviceId)
        assertEquals(BleLinkDirection.Outbound, command.direction)
        assertEquals("00000000-0000-0000-0000-000000000001", command.uuid)
        assertEquals(listOf(1u.toUByte(), 2u.toUByte(), 3u.toUByte()), command.data)
    }

    @Test
    fun fullUnsignedRevisionsNeverPassThroughDouble() {
        val message =
            """{"SetStatusItem":{"surface_id":"s","revision":18446744073709551615,"item":""" +
                """{"items":[],"show_window_label":"Show","tooltip":""}}}"""
        val command = ContractJson.decodeCommand(message) as Command.SetStatusItem

        assertEquals(ULong.MAX_VALUE, command.revision)
        val written = Json.parseToJsonElement(ContractJson.encodeCommand(command)).jsonObject
        assertEquals(
            "18446744073709551615",
            written
                .getValue("SetStatusItem")
                .jsonObject
                .getValue("revision")
                .jsonPrimitive.content,
        )
    }

    @Test
    fun theComparatorRejectsRoundedUnsignedValues() {
        assertNotNull(
            WireValues.difference(Json.parseToJsonElement("18446744073709551615"), Json.parseToJsonElement("1.8446744073709552e19")),
        )
    }

    @Test
    fun refusalDiagnosticsContainNoPayloadOrCauseSnippet() {
        val invalid =
            listOf(
                """{"s3cret":{}}""",
                """{"HardwareError":{"transport":"s3cret","error":7}}""",
                """{"HardwareError":{"transport":"s3cret"}}""",
                """{"HardwareError":{"transport":"x","transport":"s3cret","error":"e"}}""",
                """{"ActionActivated":{"surface_id":"s3cret\u0001","interaction_id":"a"}}""",
                """{"BleConnected":{"device_id":"p","direction":"s3cret"}}""",
                """{"QrScanned":{"data":"s3cret"},"QrScanned":{"data":"x"}}""",
                """{"QrScanned":{"data":"s3cret"}} trailing""",
                """{"QrScanned":{"data":"s3cret"""",
                """"s3cret"""",
            )
        invalid.forEach { message ->
            val error = assertThrows(ContractJsonException::class.java) { ContractJson.decodeEvent(message) }
            assertFalse(error.stackTraceToString().contains("s3cret"))
        }
    }
}
