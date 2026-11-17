// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CommandContract
import EventContract
import Foundation

public enum ContractJSONError: Error, Equatable {
    case invalid(String)
}

public enum ContractJSON {
    public static func decodeCommand(_ data: Data) throws -> Command {
        try decode("command", as: Command.self, data: data)
    }

    public static func decodeEvent(_ data: Data) throws -> Event {
        try decode("event", as: Event.self, data: data)
    }

    public static func decodeBoundary(_ data: Data) throws -> Event {
        try decode("boundary", as: Event.self, data: data)
    }

    public static func encodeCommand(_ value: Command) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func encodeEvent(_ value: Event) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ root: String, as type: T.Type, data: Data) throws -> T {
        try DuplicateKeyDetector.validate(data)
        let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        var schema = Schema.shared
        let normalized = try schema.normalize(root: root, value: json)
        let encoded = try JSONSerialization.data(withJSONObject: normalized, options: [.fragmentsAllowed])
        return try JSONDecoder().decode(type, from: encoded)
    }
}
