#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Streaming Kotlin writers: byte payloads must not become JSON DOM nodes."""


class Writer:
    def __init__(self, codec):
        self.codec = codec
        self.model = codec.model
        self.reference = codec.reference
        self.literal = codec.literal

    def value(self, schema, value, where, pad="    ", depth=0):
        if "$ref" in schema:
            name = schema["$ref"].removeprefix("#/definitions/")
            return [f"{pad}write{name}(w, {value})"]
        if "allOf" in schema:
            return self.value(schema["allOf"][0], value, where, pad, depth)
        inner = self.codec.nonnull(schema)
        if inner is not None:
            return [f"{pad}if ({value} == null) {{", f"{pad}    w.nullValue()", f"{pad}}} else {{",
                    *self.value(inner, value, where, pad + "    ", depth), f"{pad}}}"]
        kind = schema["type"]
        if kind == "string":
            refine = self.reference.BEYOND_THE_SCHEMA.get(where)
            if refine:
                method = {"Rd.Identifier": "identifier", "Rd.NoControlCharacters": "noControls"}[refine]
                value = f"Rd.{method}({value})"
            return [f"{pad}w.string({value}, {schema.get('minLength', 0)}, {schema.get('maxLength', -1)})"]
        if kind == "boolean":
            return [f"{pad}w.bool({value})"]
        if kind in ("number", "integer"):
            return [f"{pad}w.number({value}.toString())"]
        if kind == "array":
            element = f"e{depth}"
            return [f"{pad}w.beginArray({value}.size, {schema.get('minItems', 0)}, {schema.get('maxItems', -1)})",
                    f"{pad}for ({element} in {value}) {{",
                    *self.value(schema["items"], element, where + "[]", pad + "    ", depth + 1),
                    f"{pad}}}", f"{pad}w.endArray()"]
        raise self.reference.Unsupported(f"Kotlin writer cannot write {where}")

    def fields(self, schema, where, value="value", pad="    "):
        lines = [f"{pad}w.beginObject()"]
        required = set(schema.get("required", []))
        for wire, prop in schema.get("properties", {}).items():
            field = f"{value}.`{self.codec.property_name(wire)}`"
            optional = wire not in required and ("default" not in prop or self.codec.generator.type_of(prop).endswith("?"))
            prefix = pad
            if optional:
                lines.append(f"{pad}if ({field} != null) {{")
                prefix += "    "
            lines.append(f"{prefix}w.name({self.literal(wire)})")
            lines += self.value(prop, field, where + "." + wire, prefix)
            if optional:
                lines.append(f"{pad}}}")
        return lines + [f"{pad}w.endObject()"]

    def emit(self, name, schema, kind):
        lines = [f"internal fun write{name}(w: WireOutput, value: {name}) {{"]
        if kind == "struct":
            value = "value"
            if name in self.reference.CHECKED_TYPES:
                lines.append("    val checked = Rd.qrPlacement(value)")
                value = "checked"
            lines += self.fields(schema, name, value)
        elif kind == "enum":
            lines += ["    w.string(value.wireValue)"]
        else:
            lines += ["    when (value) {"]
            for variant in self.model.variants(schema, name):
                for wire in variant.get("enum", []):
                    lines += [f"        {name}.{self.reference.pascal(wire)} -> w.string({self.literal(wire)})"]
                for wire, payload in variant.get("properties", {}).items():
                    lines += [f"        is {name}.{self.reference.pascal(wire)} -> {{", "            w.beginObject()",
                              f"            w.name({self.literal(wire)})"]
                    where = name + "." + wire
                    if payload.get("type") == "object":
                        lines += self.fields(payload, where, pad="            ")
                    else:
                        lines += self.value(payload, "value.value", where, "            ")
                    lines += ["            w.endObject()", "        }"]
            lines += ["    }"]
        return lines + ["}"]
