// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
@testable import VauchiContract
import XCTest

final class ContractJSONTests: XCTestCase {
    func testMissingCapabilityDefaultsAreApplied() throws {
        let input = #"{"HardwareCapabilitiesReported":{"capabilities":{}}}"#
        let value = try ContractJSON.decodeEvent(input.utf8Data)
        let encoded = try ContractJSON.encodeEvent(value)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let event = decoded?["HardwareCapabilitiesReported"] as? [String: Any]
        let capabilities = event?["capabilities"] as? [String: Any]
        XCTAssertEqual(capabilities?["can_seal_user_presence"] as? Bool, false)
        XCTAssertEqual(capabilities?["audio"] as? String, "None")
    }

    func testFixedUuidArrayLengthIsEnforced() throws {
        let short = """
        {"BleAdvertisementObserved":{"id":"peer","rssi":-40,
        "service_uuids":[{"Uuid16":[1]}]}}
        """.utf8Data
        XCTAssertThrowsError(try ContractJSON.decodeEvent(short))

        let exact = """
        {"BleAdvertisementObserved":{"id":"peer","rssi":-40,
        "service_uuids":[{"Uuid16":[1, 2]}]}}
        """.utf8Data
        _ = try ContractJSON.decodeEvent(exact)
    }

    func testU32OverflowIsRejected() throws {
        let input = """
        {"ScheduleWakeup":{"earliest_secs":4294967296,"deadline_secs":1,
        "min_interval_secs":1,"delay_millis":1}}
        """.utf8Data
        XCTAssertThrowsError(try ContractJSON.decodeCommand(input))
    }

    func testEventTextLimitIsRejected() throws {
        let oversized = String(repeating: "x", count: 4097)
        let prefix = #"{"ValueChanged":{"surface_id":"s","binding_id":"b","value":{"text":""#
        let input = (prefix + oversized + #""}}"#).utf8Data
        XCTAssertThrowsError(try ContractJSON.decodeBoundary(input))
    }

    func testExplicitNullBooleanIsRejected() throws {
        let input = #"{"HardwareCapabilitiesReported":{"capabilities":{"has_camera":null}}}"#
        XCTAssertThrowsError(try ContractJSON.decodeEvent(input.utf8Data))
    }

    func testUnbalancedContainersAreRejected() {
        for input in ["}", "]", "{\"QrDisplay\":{]}"] {
            XCTAssertThrowsError(try ContractJSON.decodeCommand(input.utf8Data))
        }
    }

    func testFixtureCommandsAndEventsRoundTrip() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "schema/presentation_contract_v1",
            withExtension: "json"
        ))
        let fixture = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        for command in try XCTUnwrap(fixture["initial_commands"] as? [Any]) {
            let data = try JSONSerialization.data(withJSONObject: command)
            _ = try ContractJSON.encodeCommand(ContractJSON.decodeCommand(data))
        }
        for step in try XCTUnwrap(fixture["steps"] as? [[String: Any]]) {
            let eventData = try JSONSerialization.data(withJSONObject: XCTUnwrap(step["event"]))
            _ = try ContractJSON.encodeEvent(ContractJSON.decodeEvent(eventData))
            for command in try XCTUnwrap(step["commands"] as? [Any]) {
                let data = try JSONSerialization.data(withJSONObject: command)
                _ = try ContractJSON.encodeCommand(ContractJSON.decodeCommand(data))
            }
        }
    }
}

private extension String {
    var utf8Data: Data {
        Data(utf8)
    }
}
