// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

struct Schema {
    static let shared = Schema()

    private let roots: [String: Any]
    private var definitions: [String: Any] = [:]
    private var boundaryMode = false

    private init() {
        guard let url = Bundle.module.url(forResource: "schema/vauchi-contract-v1", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let roots = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            fatalError("embedded contract schema is unavailable")
        }
        self.roots = roots
    }

    mutating func normalize(root: String, value: Any) throws -> Any {
        let schemaRoot = root == "boundary" ? "event" : root
        guard let rootSchema = roots[schemaRoot] as? [String: Any] else {
            throw ContractJSONError.invalid("unknown contract root \(root)")
        }
        definitions = rootSchema["definitions"] as? [String: Any] ?? [:]
        boundaryMode = root == "boundary"
        return try normalize(schema: rootSchema, value: value, path: root)
    }

    private func normalize(schema: [String: Any], value: Any, path: String = "", field: String = "") throws -> Any {
        if let reference = schema["$ref"] as? String {
            guard reference.hasPrefix("#/definitions/"), let name = reference.split(separator: "/").last,
                  let target = definitions[String(name)] as? [String: Any]
            else {
                throw ContractJSONError.invalid("unresolvable schema reference \(reference)")
            }
            return try normalize(schema: target, value: value, path: String(name))
        }
        if let constant = schema["const"] {
            try expect(constant, value: value)
        }
        if let alternatives = schema["enum"] as? [Any] {
            guard alternatives.contains(where: { valuesEqual($0, value) }) else {
                throw ContractJSONError.invalid("value is outside the accepted enum")
            }
        }
        if let alternatives = schemaAlternatives(schema) {
            return try normalizeAlternatives(
                alternatives: alternatives,
                title: schema["title"] as? String ?? "untitled schema",
                path: path,
                value: value
            )
        }
        let types = schemaTypes(schema)
        if types.contains("null"), value is NSNull {
            return value
        }
        if types == ["null"] {
            throw ContractJSONError.invalid("expected null")
        }
        if types.contains("object") {
            return try normalizeObject(schema: schema, path: path, value: value)
        }
        if types.contains("array") {
            return try normalizeArray(schema: schema, path: path, value: value)
        }
        return try normalizePrimitive(schema: schema, value: value, path: path, field: field)
    }

    private func schemaAlternatives(_ schema: [String: Any]) -> [[String: Any]]? {
        for key in ["oneOf", "anyOf"] {
            if let alternatives = schema[key] as? [[String: Any]] {
                return alternatives
            }
        }
        return nil
    }

    private func normalizePrimitive(
        schema: [String: Any],
        value: Any,
        path: String,
        field: String
    ) throws -> Any {
        let types = schemaTypes(schema)
        if types.contains("integer") || types.contains("number") {
            try normalizeNumber(schema: schema, value: value)
        }
        if types.contains("boolean") {
            guard value is Bool else { throw ContractJSONError.invalid("expected boolean") }
        }
        if types.contains("string") {
            return try normalizeString(schema: schema, value: value, path: path, field: field)
        }
        return value
    }

    private func normalizeString(
        schema: [String: Any],
        value: Any,
        path: String,
        field: String
    ) throws -> Any {
        guard let string = value as? String else { throw ContractJSONError.invalid("expected string") }
        let length = string.utf8.count
        if let minimum = schema["minLength"] as? Int, length < minimum {
            throw ContractJSONError.invalid("string is shorter than \(minimum)")
        }
        if let maximum = schema["maxLength"] as? Int, length > maximum {
            throw ContractJSONError.invalid("string is longer than \(maximum)")
        }
        if boundaryMode && path == "InputValue" && field == "text", length > 4096 {
            throw ContractJSONError.invalid("text exceeds 4096 bytes")
        }
        let isBleObservation = path == "BleAdvertisementObservation"
        if schema["pattern"] != nil || isBleObservation,
           string.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            throw ContractJSONError.invalid("string contains a control character")
        }
        return value
    }

    private func normalizeAlternatives(
        alternatives: [[String: Any]],
        title: String,
        path: String,
        value: Any
    ) throws -> Any {
        for alternative in alternatives {
            if let constant = alternative["const"] as? String, let object = value as? [String: Any] {
                if let tag = object["type"] as? String, tag == constant {
                    return try normalize(schema: alternative, value: value, path: path)
                }
                if object.count == 1, let tag = object.keys.first, tag == constant {
                    return try normalize(schema: alternative, value: value, path: path)
                }
            }
            if let object = value as? [String: Any], object.count == 1,
               let tag = object.keys.first,
               let required = alternative["required"] as? [String], required.contains(tag),
               let properties = alternative["properties"] as? [String: Any], properties[tag] != nil {
                return try normalize(schema: alternative, value: value, path: path)
            }
        }

        var accepted: [Any] = []
        for alternative in alternatives {
            do {
                try accepted.append(normalize(schema: alternative, value: value, path: path))
            } catch {
                continue
            }
        }
        guard accepted.count == 1, let result = accepted.first else {
            throw ContractJSONError.invalid(
                "value matches \(accepted.count) contract variants in \(title)"
            )
        }
        return result
    }

    private func normalizeObject(schema: [String: Any], path: String, value: Any) throws -> Any {
        guard var object = value as? [String: Any] else {
            throw ContractJSONError.invalid("expected object")
        }
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let required = schema["required"] as? [String] ?? []
        for key in required where object[key] == nil {
            guard let property = properties[key] as? [String: Any], property["default"] != nil else {
                throw ContractJSONError.invalid("missing required key \(key)")
            }
        }
        for (key, rawProperty) in properties {
            guard let property = rawProperty as? [String: Any] else { continue }
            if object[key] == nil, let defaultValue = property["default"] {
                object[key] = defaultValue
            }
            if let current = object[key] {
                object[key] = try normalize(schema: property, value: current, path: path, field: key)
            }
        }
        return object
    }

    private func normalizeArray(schema: [String: Any], path: String, value: Any) throws -> Any {
        guard let array = value as? [Any] else {
            throw ContractJSONError.invalid("expected array")
        }
        if let minimum = schema["minItems"] as? Int, array.count < minimum {
            throw ContractJSONError.invalid("array has \(array.count) items, minimum is \(minimum)")
        }
        if let maximum = schema["maxItems"] as? Int, array.count > maximum {
            throw ContractJSONError.invalid("array has \(array.count) items, maximum is \(maximum)")
        }
        if let prefix = schema["prefixItems"] as? [[String: Any]] {
            guard prefix.count == array.count else {
                throw ContractJSONError.invalid("fixed array requires \(prefix.count) items")
            }
            return try zip(prefix, array).map { itemSchema, item in
                try normalize(schema: itemSchema, value: item, path: path)
            }
        }
        if let itemSchema = schema["items"] as? [String: Any] {
            return try array.map { try normalize(schema: itemSchema, value: $0, path: path) }
        }
        return array
    }

    func schemaTypes(_ schema: [String: Any]) -> [String] {
        if let type = schema["type"] as? String {
            return [type]
        }
        if let types = schema["type"] as? [String] {
            return types
        }
        return []
    }

    private func expect(_ expected: Any, value: Any) throws {
        guard valuesEqual(expected, value) else {
            throw ContractJSONError.invalid("value does not match const")
        }
    }

    private func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case let (left as String, right as String): return left == right
        case let (left as Bool, right as Bool): return left == right
        case let (left as NSNumber, right as NSNumber): return left.stringValue == right.stringValue
        case is (NSNull, NSNull): return true
        case let (left as [Any], right as [Any]):
            return left.count == right.count && zip(left, right).allSatisfy(valuesEqual)
        case let (left as [String: Any], right as [String: Any]):
            return left.keys == right.keys && left.allSatisfy { key, value in
                guard let other = right[key] else { return false }
                return valuesEqual(value, other)
            }
        default: return false
        }
    }
}
