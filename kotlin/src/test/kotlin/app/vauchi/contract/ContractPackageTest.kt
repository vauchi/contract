// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class ContractPackageTest {
    private val checkout = File(System.getProperty("vauchi.contractCheckout"))

    @Test
    fun theLibraryReportsTheContractReleaseVersion() {
        val manifest = File(checkout, "Cargo.toml").readText()
        val expected = Regex("""(?m)^version\s*=\s*"([^"]+)"""").find(manifest)!!.groupValues[1]

        assertEquals(expected, ContractInfo.VERSION)
    }

    @Test
    fun thePublishedFixtureIsExactlyTheSharedReplayFixture() {
        val expected = File(checkout, "fixtures/protocol_conformance_v1.json").readText()

        assertEquals(expected, ContractInfo.protocolConformanceV1())
    }
}
