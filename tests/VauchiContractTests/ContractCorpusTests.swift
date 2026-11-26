// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
@testable import VauchiContract
import XCTest

final class ContractCorpusTests: XCTestCase {
    func testPreparedBleFixtureKeepsAllEncodedData() throws {
        let url = URL(fileURLWithPath: "fixtures/prepared_ble_v1.json")
        let fixture = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertEqual(fixture["schema_version"] as? Int, 1)
        let commands = try XCTUnwrap(fixture["commands"] as? [[String: Any]])
        XCTAssertEqual(commands.count, 2)
        for expected in commands {
            let input = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])
            let encoded = try ContractJSON.encodeCommand(ContractJSON.decodeCommand(input))
            let actual = try JSONSerialization.jsonObject(with: encoded)
            XCTAssertEqual(
                try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys]),
                input,
                "prepared data must survive the public codec"
            )
        }
    }

    func testAllOracleCasesAndCorpusMessages() throws {
        let directory = ProcessInfo.processInfo.environment["VAUCHI_ORACLE_DIR"] ?? "cache/oracle"
        for name in ["cases", "corpus"] {
            let expected = try expectedResults(directory: directory, name: name)
            let url = URL(fileURLWithPath: "\(directory)/\(name).jsonl")
            let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            for (index, line) in lines.enumerated() {
                if line.isEmpty {
                    continue
                }
                let request = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
                let id = request["id"] as? String ?? "\(name):\(index)"
                let kind = kindFor(id)
                guard let expected = expected[id] else {
                    return XCTFail("\(id): missing oracle result")
                }
                do {
                    if kind == "command" {
                        _ = try ContractJSON.decodeCommand(Data(XCTUnwrap((request["json"] as? String)?.utf8)))
                    } else if kind == "boundary" {
                        _ = try ContractJSON.decodeBoundary(Data(XCTUnwrap((request["json"] as? String)?.utf8)))
                    } else {
                        _ = try ContractJSON.decodeEvent(Data(XCTUnwrap((request["json"] as? String)?.utf8)))
                    }
                    XCTAssertTrue(expected, "\(id): Rust rejected but Swift accepted")
                } catch {
                    XCTAssertFalse(expected, "\(id): Rust accepted but Swift rejected: \(error)")
                }
            }
        }
    }

    private func expectedResults(directory: String, name: String) throws -> [String: Bool] {
        let url = URL(fileURLWithPath: "\(directory)/expected-\(name).jsonl")
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        var results: [String: Bool] = [:]
        for line in lines where !line.isEmpty {
            let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try XCTUnwrap(record["id"] as? String)
            results[id] = record["ok"] as? Bool ?? false
        }
        return results
    }
}

private func kindFor(_ id: String) -> String {
    if id.hasPrefix("boundary_") {
        return "boundary"
    }
    let eventPrefixes = [
        "event_", "ble_id_", "uuid_bytes_", "fixture_event_",
        "step_event_", "file_picker_event_",
    ]
    return eventPrefixes.contains(where: id.hasPrefix) ? "event" : "command"
}
