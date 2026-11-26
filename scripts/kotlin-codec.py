#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Schema-driven Kotlin wire readers and writers for generate-kotlin.py."""

import json


class Codec:
    def __init__(self, generator, reference, literal, property_name, writer):
        self.generator = generator
        self.model = generator.model
        self.reference = reference
        self.literal = literal
        self.property_name = property_name
        self.writer = writer(self)

    @staticmethod
    def nonnull(schema):
        if "anyOf" in schema:
            return next(item for item in schema["anyOf"] if item != {"type": "null"})
        if isinstance(schema.get("type"), list):
            return dict(schema, type=next(item for item in schema["type"] if item != "null"))
        return None

    def read(self, schema, value, where, depth=0):
        if "$ref" in schema:
            name = schema["$ref"].removeprefix("#/definitions/")
            return f"read{name}({value})"
        if "allOf" in schema:
            return self.read(schema["allOf"][0], value, where, depth)
        inner = self.nonnull(schema)
        if inner is not None:
            read = self.read(inner, value, where, depth)
            return f"(if ({value}.json == JsonNull) null else {read})"
        kind = schema["type"]
        if kind == "string":
            result = f"Rd.string({value}, {schema.get('minLength', 0)}, {schema.get('maxLength', -1)})"
            refine = self.reference.BEYOND_THE_SCHEMA.get(where)
            if refine:
                method = {"Rd.Identifier": "identifier", "Rd.NoControlCharacters": "noControls"}[refine]
                result = f"Rd.{method}({result})"
            return result
        if kind == "boolean":
            return f"Rd.bool({value})"
        if kind in ("integer", "number"):
            method = {
                "uint8": "u8", "uint16": "u16", "uint32": "u32", "uint64": "u64", "uint": "u64",
                "int16": "i16", "int32": "i32", "float": "f32", "double": "f64",
            }[schema["format"]]
            return f"Rd.{method}({value})"
        if kind == "array":
            name = f"e{depth}"
            read = self.read(schema["items"], name, where + "[]", depth + 1)
            return f"Rd.list({value}, {schema.get('minItems', 0)}, {schema.get('maxItems', -1)}) {{ {name} -> {read} }}"
        raise self.reference.Unsupported(f"Kotlin codec cannot read {where}")

    def read_object(self, schema, where, construct, value="v", indent="    "):
        properties = schema.get("properties", {})
        required = set(schema.get("required", []))
        closed = schema.get("additionalProperties", True) is False or where in self.reference.CHECKED_TYPES
        names = ", ".join(self.literal(wire) for wire in properties)
        lines = [f"{indent}{value}.objectFields(setOf({names}), {str(closed).lower()})"]
        if not properties:
            return lines + [f"{indent}return {construct}"]
        checked = where in self.reference.CHECKED_TYPES
        lines.append(f"{indent}return {'Rd.qrPlacement(' if checked else ''}{construct}(")
        for wire, prop in properties.items():
            read = self.read(prop, f"{value}.required({self.literal(wire)})", f"{where}.{wire}")
            if wire not in required:
                default = "null"
                if "default" in prop:
                    text = self.literal(json.dumps(prop["default"], separators=(",", ":")))
                    default = self.read(prop, f"WireValue(Json.parseToJsonElement({text}))", f"{where}.{wire}")
                member_read = self.read(prop, "f", f"{where}.{wire}")
                read = f"{value}.member({self.literal(wire)})?.let {{ f -> {member_read} }} ?: {default}"
            lines.append(f"{indent}    `{self.property_name(wire)}` = {read},")
        lines.append(f"{indent}){')' if checked else ''}")
        return lines

    def emit(self, name, schema, kind):
        lines = [f"internal fun read{name}(v: WireValue): {name} {{"]
        if kind == "struct":
            lines += self.read_object(schema, name, name)
        elif kind == "enum":
            lines += [f"    val wire = Rd.string(v)", f"    return {name}.entries.firstOrNull {{ it.wireValue == wire }} ?: refused()"]
        else:
            variants = self.model.variants(schema, name)
            units = [wire for variant in variants for wire in variant.get("enum", [])]
            if units:
                lines += ["    if (v.json is JsonPrimitive && v.json.isString) {", "        return when (Rd.string(v)) {"]
                lines += [f"            {self.literal(wire)} -> {name}.{self.reference.pascal(wire)}" for wire in units]
                lines += ["            else -> refused()", "        }", "    }"]
            lines += ["    val (tag, payload) = v.variant()", "    return when (tag) {"]
            for variant in variants:
                for wire, payload in variant.get("properties", {}).items():
                    construct = f"{name}.{self.reference.pascal(wire)}"
                    lines.append(f"        {self.literal(wire)} -> {{")
                    if payload.get("type") == "object":
                        # Local functions keep the generated constructor identical
                        # to a normal struct reader without non-local returns.
                        lines += [f"            fun readPayload(): {construct} {{"]
                        lines += self.read_object(payload, name + "." + wire, construct, "payload", "                ")
                        lines += ["            }", "            readPayload()"]
                    else:
                        lines += [f"            {construct}({self.read(payload, 'payload', name + '.' + wire)})"]
                    lines.append("        }")
            lines += ["        else -> refused()", "    }"]
        lines += ["}", "", *self.writer.emit(name, schema, kind)]
        return lines

    def generate(self):
        imports = [f"import kotlinx.serialization.json.{name}" for name in ("Json", "JsonArray", "JsonElement", "JsonNull", "JsonPrimitive")]
        blocks = [imports]
        for name, schema in sorted(self.model.definitions.items()):
            blocks.append(self.emit(name, schema, self.model.kinds[name]))
        result = {"TypesCodec.g.kt": self.generator.file(blocks)}
        for name, schema in self.model.roots.items():
            result[f"{name}Codec.g.kt"] = self.generator.file([imports, self.emit(name, schema, "union")])
        return result
