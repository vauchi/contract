// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class OracleParityTest {
    private class Probe(
        val id: String,
        val kind: String,
        val json: String,
        val accepted: Boolean,
        val value: JsonElement?,
    )

    private val arrayStruct = "event:HardwareCapabilitiesReported/capabilities:array"
    private val everything = load()
    private val cases = everything.filter { it.id != arrayStruct }

    private fun load(): List<Probe> {
        val configured = System.getenv("VAUCHI_ORACLE_DIR")
        val directory =
            if (configured.isNullOrEmpty()) {
                File(
                    System.getProperty("vauchi.contractCheckout"),
                    "cache/oracle",
                )
            } else {
                File(configured)
            }
        return listOf("cases", "corpus", "mutants").flatMap { name ->
            fun lines(prefix: String) =
                File(directory, "$prefix$name.jsonl").readLines().filter { it.isNotBlank() }.map {
                    Json.parseToJsonElement(it).jsonObject
                }
            val expected = lines("expected-").associateBy { it.getValue("id").jsonPrimitive.content }
            lines("").filter { it.getValue("kind").jsonPrimitive.content != "boundary" }.map { request ->
                val id = request.getValue("id").jsonPrimitive.content
                val result = expected.getValue(id)
                Probe(
                    id,
                    request.getValue("kind").jsonPrimitive.content,
                    request.getValue("json").jsonPrimitive.content,
                    result.getValue("ok").jsonPrimitive.content == "true",
                    result["value"],
                )
            }
        }
    }

    private fun reencode(
        probe: Probe,
        message: String = probe.json,
    ): String? =
        try {
            when (probe.kind) {
                "command" -> ContractJson.encodeCommand(ContractJson.decodeCommand(message))
                "event" -> ContractJson.encodeEvent(ContractJson.decodeEvent(message))
                else -> error("unknown oracle kind")
            }
        } catch (_: ContractJsonException) {
            null
        }

    @Test
    fun theOracleIncludesBothOutcomesForBothMessageKinds() {
        assertTrue("oracle corpus is unexpectedly small", cases.size >= 300)
        assertEquals(
            setOf("command" to true, "command" to false, "event" to true, "event" to false),
            cases.map { it.kind to it.accepted }.toSet(),
        )
        val labels =
            listOf(":raw_-0", ":raw_-0.0", ":raw_1e400", ":raw_NaN", ":items_1", ":nested_127", ":nested_128", ":placement_1000_1_0")
        labels.forEach { label ->
            assertTrue("missing oracle probe $label", everything.any { it.id.endsWith(label) })
        }
    }

    @Test
    fun theDocumentedSchemaExceptionRemainsAcceptedOnlyByRust() {
        val probe = everything.single { it.id == arrayStruct }
        assertEquals(true, probe.accepted)
        assertNull(reencode(probe))
    }

    @Test
    fun everyMessageAgreesWithRustAcceptance() {
        val differences =
            cases
                .filter {
                    (reencode(it) != null) != it.accepted
                }.map { "${it.id}: Rust ${if (it.accepted) "accepts" else "rejects"}" }
        assertEquals(emptyList<String>(), differences)
    }

    @Test
    fun everyAcceptedMessageRetainsTheRustWireValue() {
        val differences =
            cases.filter { it.accepted }.mapNotNull { probe ->
                val written = reencode(probe)
                val difference = if (written == null) "refused" else WireValues.difference(probe.value!!, Json.parseToJsonElement(written))
                difference?.let { "${probe.id}: $it" }
            }
        assertEquals(emptyList<String>(), differences)
    }

    @Test
    fun rewritingAnAcceptedMessageIsStable() {
        cases.filter { it.accepted }.forEach { probe ->
            val once = reencode(probe) ?: error("${probe.id}: unexpectedly refused")
            assertEquals(probe.id, once, reencode(probe, once))
        }
    }
}
