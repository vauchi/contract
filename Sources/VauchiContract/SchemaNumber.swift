// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

extension Schema {
    func normalizeNumber(schema: [String: Any], value: Any) throws {
        guard let number = value as? NSNumber, number.objCType.pointee != 99 else {
            throw ContractJSONError.invalid("expected number")
        }
        if schemaTypes(schema).contains("integer"), number.doubleValue.rounded() != number.doubleValue {
            throw ContractJSONError.invalid("expected integer")
        }
        let actual = Decimal(string: number.stringValue, locale: Locale(identifier: "en_US_POSIX"))
        guard let actual else { throw ContractJSONError.invalid("invalid number") }
        if let rawMinimum = schema["minimum"] as? NSNumber,
           let minimum = Decimal(string: rawMinimum.stringValue, locale: Locale(identifier: "en_US_POSIX")),
           actual < minimum {
            throw ContractJSONError.invalid("number is below minimum")
        }
        if let rawMaximum = schema["maximum"] as? NSNumber,
           let maximum = Decimal(string: rawMaximum.stringValue, locale: Locale(identifier: "en_US_POSIX")),
           actual > maximum {
            throw ContractJSONError.invalid("number is above maximum")
        }
        if let format = schema["format"] as? String {
            let ranges: [String: (String, String)] = [
                "uint8": ("0", "255"),
                "uint16": ("0", "65535"),
                "uint32": ("0", "4294967295"),
                "uint64": ("0", "18446744073709551615"),
                "int8": ("-128", "127"),
                "int16": ("-32768", "32767"),
                "int32": ("-2147483648", "2147483647"),
                "int64": ("-9223372036854775808", "9223372036854775807"),
            ]
            if let (rawMinimum, rawMaximum) = ranges[format],
               let minimum = Decimal(string: rawMinimum, locale: Locale(identifier: "en_US_POSIX")),
               let maximum = Decimal(string: rawMaximum, locale: Locale(identifier: "en_US_POSIX")),
               actual < minimum || actual > maximum {
                throw ContractJSONError.invalid("number is outside \(format)")
            }
        }
    }
}
