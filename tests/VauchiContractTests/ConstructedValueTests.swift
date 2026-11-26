// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CommandContract
import EventContract
import Foundation
import VauchiContract
import XCTest

final class ConstructedValueTests: XCTestCase {
    private func advertisement(_ services: [BleServiceUUID], rssi: Int = -42) throws -> Event {
        let baseline = Data(#"{"BleAdvertisementObserved":{"id":"native-id","rssi":-42,"service_uuids":[]}}"#.utf8)
        guard case let .eventClass(body) = try ContractJSON.decodeEvent(baseline) else {
            throw ContractJSONError.invalid("expected event payload")
        }
        return .eventClass(body.with(bleAdvertisementObserved:
            BleAdvertisementObservation(id: "native-id", rssi: rssi, serviceUuids: services)))
    }

    func testConstructedUuidWidthsAreValidatedBeforeEncoding() throws {
        for (uuid, message) in [
            (
                BleServiceUUID(uuid16: [1], uuid32: nil, uuid128: nil, normalized: nil),
                "array has 1 items, minimum is 2"
            ),
            (
                BleServiceUUID(uuid16: nil, uuid32: [1, 2, 3, 4, 5], uuid128: nil, normalized: nil),
                "array has 5 items, maximum is 4"
            ),
            (
                BleServiceUUID(uuid16: nil, uuid32: nil, uuid128: Array(repeating: 0, count: 15), normalized: nil),
                "array has 15 items, minimum is 16"
            ),
            (
                BleServiceUUID(uuid16: nil, uuid32: nil, uuid128: nil, normalized: Array(repeating: 0, count: 17)),
                "array has 17 items, maximum is 16"
            ),
        ] {
            let value = try advertisement([uuid])
            XCTAssertThrowsError(try ContractJSON.encodeEvent(value)) { error in
                XCTAssertEqual(error as? ContractJSONError, .invalid(message))
            }
        }
    }

    func testConstructedServiceListsCannotExceed32Items() throws {
        let uuid = BleServiceUUID(uuid16: [1, 2], uuid32: nil, uuid128: nil, normalized: nil)
        let value = try advertisement(Array(repeating: uuid, count: 33))
        XCTAssertThrowsError(try ContractJSON.encodeEvent(value)) { error in
            XCTAssertEqual(error as? ContractJSONError, .invalid("array has 33 items, maximum is 32"))
        }
    }

    func testConstructedByteAndSignedScalarRangesAreValidated() throws {
        for byte in [-1, 256] {
            let uuid = BleServiceUUID(uuid16: [byte, 0], uuid32: nil, uuid128: nil, normalized: nil)
            let value = try advertisement([uuid])
            XCTAssertThrowsError(try ContractJSON.encodeEvent(value)) { error in
                XCTAssertEqual(error as? ContractJSONError,
                               .invalid(byte < 0 ? "number is below minimum" : "number is outside uint8"))
            }
        }
        let value = try advertisement([], rssi: -32769)
        XCTAssertThrowsError(try ContractJSON.encodeEvent(value)) { error in
            XCTAssertEqual(error as? ContractJSONError, .invalid("number is outside int16"))
        }
    }

    func testConstructedCommandsValidateUnsignedScalarRanges() throws {
        let baseline = Data(#"""
        {"ScheduleWakeup":{"earliest_secs":1,"deadline_secs":2,
        "min_interval_secs":1,"delay_millis":1}}
        """#.utf8)
        guard case let .commandClass(body) = try ContractJSON.decodeCommand(baseline) else {
            throw ContractJSONError.invalid("expected command payload")
        }
        let wakeup = try XCTUnwrap(body.scheduleWakeup)
        for delay in [-1, 4_294_967_296] {
            let value = Command.commandClass(body.with(scheduleWakeup: wakeup.with(delayMillis: delay)))
            XCTAssertThrowsError(try ContractJSON.encodeCommand(value)) { error in
                XCTAssertEqual(error as? ContractJSONError,
                               .invalid(delay < 0 ? "number is below minimum" : "number is outside uint32"))
            }
        }
    }

    func testAmbiguousConstructedValuesAreRejectedWithoutPayloadsInErrors() throws {
        let uuid = BleServiceUUID(uuid16: [91, 92], uuid32: nil,
                                  uuid128: Array(repeating: 93, count: 16), normalized: nil)
        let value = try advertisement([uuid])
        XCTAssertThrowsError(try ContractJSON.encodeEvent(value)) { error in
            XCTAssertEqual(error as? ContractJSONError,
                           .invalid("value matches 2 contract variants in untitled schema"))
        }
    }

    func testExactArrayBoundsAndMaximumUnsignedValuesStillRoundTrip() throws {
        let uuid = BleServiceUUID(uuid16: nil, uuid32: nil,
                                  uuid128: Array(repeating: 255, count: 16), normalized: nil)
        for count in [0, 32] {
            let value = try advertisement(Array(repeating: uuid, count: count))
            let wire = try ContractJSON.encodeEvent(value)
            guard case let .eventClass(body) = try ContractJSON.decodeEvent(wire) else {
                return XCTFail("expected event payload")
            }
            let observed = try XCTUnwrap(body.bleAdvertisementObserved)
            XCTAssertEqual(observed.id, "native-id")
            XCTAssertEqual(observed.rssi, -42)
            XCTAssertEqual(observed.serviceUuids.count, count)
            for item in observed.serviceUuids {
                XCTAssertEqual(item.uuid128, Array(repeating: 255, count: 16))
            }
        }
        let input = Data(#"""
        {"ScheduleWakeup":{"earliest_secs":4294967295,"deadline_secs":4294967295,
        "min_interval_secs":4294967295,"delay_millis":4294967295}}
        """#.utf8)
        let wire = try ContractJSON.encodeCommand(ContractJSON.decodeCommand(input))
        guard case let .commandClass(body) = try ContractJSON.decodeCommand(wire) else {
            return XCTFail("expected command payload")
        }
        let wakeup = try XCTUnwrap(body.scheduleWakeup)
        XCTAssertEqual(wakeup.earliestSecs, 4_294_967_295)
        XCTAssertEqual(wakeup.deadlineSecs, 4_294_967_295)
        XCTAssertEqual(wakeup.minIntervalSecs, 4_294_967_295)
        XCTAssertEqual(wakeup.delayMillis, 4_294_967_295)
        let menuInput = Data(#"""
        {"SetApplicationMenu":{"surface_id":"menu-surface",
        "revision":18446744073709551615,"menus":[]}}
        """#.utf8)
        let menuWire = try ContractJSON.encodeCommand(ContractJSON.decodeCommand(menuInput))
        guard case let .commandClass(menuBody) = try ContractJSON.decodeCommand(menuWire) else {
            return XCTFail("expected menu command")
        }
        XCTAssertEqual(try XCTUnwrap(menuBody.setApplicationMenu).revision, UInt64.max)
    }
}
