// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

enum DuplicateKeyDetector {
    private struct State {
        var containers: [Bool] = []
        var keys: [Set<String>] = []
        var currentKey: String?
        var inString = false
        var escaped = false
    }

    static func validate(_ data: Data) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ContractJSONError.invalid("input is not UTF-8")
        }
        var state = State()
        for character in text {
            try consume(character, &state)
        }
    }

    private static func consume(_ character: Character, _ state: inout State) throws {
        if state.inString {
            consumeString(character, &state)
            return
        }
        switch character {
        case "\"":
            state.inString = true
            state.currentKey = ""
        case "{":
            state.containers.append(true)
            state.keys.append([])
            state.currentKey = nil
        case "}":
            try closeContainer(object: true, &state)
        case "[":
            state.containers.append(false)
            state.currentKey = nil
        case "]":
            try closeContainer(object: false, &state)
        case ":":
            try consumeColon(&state)
        default:
            if !character.isWhitespace {
                state.currentKey = nil
            }
        }
    }

    private static func closeContainer(object: Bool, _ state: inout State) throws {
        guard state.containers.last == object else {
            throw ContractJSONError.invalid("unmatched closing container")
        }
        state.containers.removeLast()
        if object {
            state.keys.removeLast()
        }
        state.currentKey = nil
    }

    private static func consumeString(_ character: Character, _ state: inout State) {
        if state.escaped {
            state.escaped = false
            state.currentKey?.append(character)
        } else if character == "\\" {
            state.escaped = true
            state.currentKey?.append(character)
        } else if character == "\"" {
            state.inString = false
        } else {
            state.currentKey?.append(character)
        }
    }

    private static func consumeColon(_ state: inout State) throws {
        if state.containers.last == true, let rawKey = state.currentKey {
            let key = try decodeKey(rawKey)
            if state.keys[state.keys.count - 1].contains(key) {
                throw ContractJSONError.invalid("duplicate object key \(key)")
            }
            state.keys[state.keys.count - 1].insert(key)
        }
        state.currentKey = nil
    }

    private static func decodeKey(_ rawKey: String) throws -> String {
        let data = Data("\"\(rawKey)\"".utf8)
        guard let key = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? String else {
            throw ContractJSONError.invalid("object key is not a string")
        }
        return key
    }
}
