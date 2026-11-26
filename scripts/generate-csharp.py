#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate the C# contract types from schema/vauchi-contract-v1.json.

The schema is what schemars derives from the Rust types, so it uses a small
regular subset of JSON Schema. Anything outside that subset stops the
generator: a silent fallback would ship a type that reads or writes
something else than Rust does.

    generate-csharp.py            check the committed files are current
    generate-csharp.py --write    regenerate them
"""

import argparse
import json
import sys
from pathlib import Path

NAMESPACE = "Vauchi.Contract"
QUALIFIER = f"global::{NAMESPACE}."
ROOTS = (("command", "Command"), ("event", "Event"))
# A nested type or a property may not reuse a member every record has.
RESERVED_MEMBERS = {"Read", "ReadPayload", "Write", "Equals", "ToString", "GetHashCode", "EqualityContract"}
INTEGERS = {
    "uint8": ("byte", "U8"),
    "uint16": ("ushort", "U16"),
    "uint32": ("uint", "U32"),
    "uint64": ("ulong", "U64"),
    # Rust `usize`: 64 bits on every target Vauchi builds for.
    "uint": ("ulong", "U64"),
    "int16": ("short", "I16"),
    "int32": ("int", "I32"),
}
NUMBERS = {"float": ("float", "F32"), "double": ("double", "F64")}
ANNOTATIONS = {"description", "deprecated", "title", "$schema"}
# Fields whose Rust type is `SurfaceId`, `InteractionId` or `BindingId`
# (contract/src/presentation.rs, `validate_identifier`): 1 to 128 bytes and
# no control character. The schema shows them as plain strings.
IDENTIFIERS = (
    "ActionSpec.interaction_id",
    "NavigationItem.interaction_id",
    "PresentationNode.Text.id",
    "PresentationNode.Input.binding_id",
    "PresentationNode.Toggle.binding_id",
    "PresentationNode.Choice.binding_id",
    "PresentationNode.Group.id",
    "PresentationNode.List.id",
    "PresentationNode.Image.id",
    "PresentationNode.Status.id",
    "PresentationNode.Qr.id",
    "PresentationNode.Confirmation.id",
    "PresentationNode.Slider.binding_id",
    "PresentationProfile.active_surface",
    "PresentationProfile.detail_surface",
    "PresentationProfile.primary_surface",
    "SurfaceSpec.surface_id",
    "Command.SetContextBar.surface_id",
    "Command.SetNavigation.surface_id",
    "Command.PresentOverlay.surface_id",
    "Command.DismissOverlay.surface_id",
    "Command.SetApplicationMenu.surface_id",
    "Command.SetStatusItem.surface_id",
    "Event.ActionActivated.interaction_id",
    "Event.ActionActivated.surface_id",
    "Event.SurfaceActivated.surface_id",
    "Event.BackRequested.surface_id",
    "Event.OverlayDismissed.surface_id",
    "Event.ValueChanged.binding_id",
    "Event.ValueChanged.surface_id",
    "Event.InputSubmitted.binding_id",
    "Event.InputSubmitted.surface_id",
    "Event.InputFocusEnded.binding_id",
    "Event.InputFocusEnded.surface_id",
    "Event.RefreshRequested.surface_id",
)
# Rules the Rust type enforces in a hand-written `Deserialize` and the schema
# does not state (vauchi/private#1348). Each is held to Rust by the oracle:
# the hand-written cases named here, and `swift-oracle-mutants.py`, which
# changes every field of every corpus message. An entry whose field has
# left the schema stops the generator.
BEYOND_THE_SCHEMA = {
    # contract/src/ble_observation.rs: `chars().any(char::is_control)`
    # (oracle case `ble_id_control`).
    "BleAdvertisementObservation.id": "Rd.NoControlCharacters",
    **{site: "Rd.Identifier" for site in IDENTIFIERS},
}
# Whole types Rust reads through a hand-written `Deserialize`: the reader
# refuses unknown fields and passes the value through the named check.
CHECKED_TYPES = {
    # contract/src/presentation/surface/nodes.rs, `QrPlacement::new`
    # (oracle cases `qr_placement_*`).
    "QrPlacement": "Rd.QrPlacement",
}


class Unsupported(Exception):
    pass


def pascal(name):
    parts = [part for part in name.replace("-", "_").split("_") if part]
    text = "".join(part[0].upper() + part[1:] for part in parts)
    if not text or not (text[0].isalpha() or text[0] == "_") or not all(c.isalnum() or c == "_" for c in text):
        raise Unsupported(f"cannot name {name!r} in C#")
    return text


def literal(text):
    return json.dumps(text, ensure_ascii=True)


def summary(schema, indent):
    description = schema.get("description") if isinstance(schema, dict) else None
    if not description:
        return []
    lines = [f"{indent}/// <summary>"]
    for line in description.splitlines():
        escaped = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        lines.append(f"{indent}/// {escaped}".rstrip())
    lines.append(f"{indent}/// </summary>")
    return lines


def only(schema, allowed, where):
    extra = set(schema) - set(allowed) - ANNOTATIONS
    if extra:
        raise Unsupported(f"{where}: unsupported keywords {sorted(extra)}")


class Type:
    """A C# type with the expressions that read and write it."""

    def __init__(self, cs, is_value, read, write):
        self.cs = cs
        self.is_value = is_value
        self.read = read  # reader variable name -> expression
        self.write = write  # (value expression, depth) -> list of statements

    @property
    def nullable(self):
        return self.cs.endswith("?")


def absent_of(inner):
    """A field Rust lets a sender leave out but not send as `null`: C# holds
    the omission as null and reads a sent value as the type itself."""
    optional = nullable_of(inner)
    return Type(optional.cs, inner.is_value, inner.read, optional.write)


def nullable_of(inner):
    if inner.nullable:
        raise Unsupported("nested nullable")

    def write(value, depth):
        name = f"x{depth}"
        body = inner.write(name, depth + 1)
        return [f"if ({value} is {{ }} {name})", "{", *[f"    {line}" for line in body], "}", "else", "{", "    w.WriteNullValue();", "}"]

    return Type(
        f"{inner.cs}?",
        inner.is_value,
        lambda r: f"({r}.TokenType == JsonTokenType.Null ? default({inner.cs}?) : {inner.read(r)})",
        write,
    )


class Generator:
    def __init__(self, schema):
        self.definitions = {}
        self.owner = {}
        self.refined = set()
        self.checked = set()
        for key, _ in ROOTS:
            for name, definition in schema[key].get("definitions", {}).items():
                if name in self.definitions and self.definitions[name] != definition:
                    raise Unsupported(f"definition {name} differs between the two roots")
                self.definitions[name] = definition
                self.owner.setdefault(name, key)
        self.roots = {name: schema[key] for key, name in ROOTS}
        for name in self.roots:
            if name in self.definitions:
                raise Unsupported(f"definition {name} collides with a root")
        self.kinds = {name: self.kind(name, definition) for name, definition in self.definitions.items()}

    # --- classification -------------------------------------------------

    @staticmethod
    def variants(schema, where):
        if "oneOf" in schema:
            only(schema, {"oneOf", "definitions"}, where)
            return schema["oneOf"]
        only(schema, {"enum", "type"}, where)
        return [schema]

    def kind(self, name, definition):
        if "oneOf" in definition or "enum" in definition:
            units_only = all("enum" in variant for variant in self.variants(definition, name))
            return "enum" if units_only else "union"
        if definition.get("type") == "object":
            return "struct"
        raise Unsupported(f"definition {name}: neither an object, an enum nor a oneOf")

    # --- types ----------------------------------------------------------

    def reference(self, schema, where):
        target = schema["$ref"]
        prefix = "#/definitions/"
        if not target.startswith(prefix) or target[len(prefix):] not in self.definitions:
            raise Unsupported(f"{where}: unresolvable reference {target}")
        name = target[len(prefix):]
        cs = QUALIFIER + name
        if self.kinds[name] == "enum":
            return Type(cs, True, lambda r: f"{cs}Json.Read(ref {r})", lambda v, d: [f"{cs}Json.Write(w, {v});"])
        return Type(cs, False, lambda r: f"{cs}.Read(ref {r})", lambda v, d: [f"{v}.Write(w);"])

    def type_of(self, schema, where):
        if "$ref" in schema:
            only(schema, {"$ref"}, where)
            return self.reference(schema, where)
        if "allOf" in schema:
            only(schema, {"allOf", "default"}, where)
            if len(schema["allOf"]) != 1:
                raise Unsupported(f"{where}: allOf with {len(schema['allOf'])} members")
            return self.type_of(schema["allOf"][0], where)
        if "anyOf" in schema:
            only(schema, {"anyOf", "default"}, where)
            members = [member for member in schema["anyOf"] if member != {"type": "null"}]
            if len(members) != 1 or len(schema["anyOf"]) != 2:
                raise Unsupported(f"{where}: anyOf is not `T or null`")
            return nullable_of(self.type_of(members[0], where))
        kind = schema.get("type")
        if isinstance(kind, list):
            if len(kind) != 2 or "null" not in kind:
                raise Unsupported(f"{where}: type list {kind}")
            base = dict(schema, type=next(item for item in kind if item != "null"))
            return nullable_of(self.type_of(base, where))
        if kind == "string":
            only(schema, {"type", "minLength", "maxLength", "default"}, where)
            if "minLength" in schema or "maxLength" in schema:
                low, high = schema.get("minLength", 0), schema.get("maxLength", -1)
                bounded = lambda r: f"Rd.String(ref {r}, {low}, {high})"
            else:
                bounded = lambda r: f"Rd.String(ref {r})"
            refine = BEYOND_THE_SCHEMA.get(where)
            if refine:
                self.refined.add(where)
            read = (lambda r: f"{refine}({bounded(r)})") if refine else bounded
            return Type("string", False, read, lambda v, d: [f"w.WriteStringValue({v});"])
        if kind == "boolean":
            only(schema, {"type", "default"}, where)
            return Type("bool", True, lambda r: f"Rd.Bool(ref {r})", lambda v, d: [f"w.WriteBooleanValue({v});"])
        if kind == "integer":
            only(schema, {"type", "format", "minimum", "default"}, where)
            fmt = schema.get("format")
            if fmt not in INTEGERS:
                raise Unsupported(f"{where}: integer format {fmt}")
            if fmt.startswith("uint") != (schema.get("minimum") == 0.0):
                raise Unsupported(f"{where}: minimum does not match {fmt}")
            cs, reader = INTEGERS[fmt]
            return Type(cs, True, lambda r: f"Rd.{reader}(ref {r})", lambda v, d: [f"w.WriteNumberValue({v});"])
        if kind == "number":
            only(schema, {"type", "format", "default"}, where)
            fmt = schema.get("format")
            if fmt not in NUMBERS:
                raise Unsupported(f"{where}: number format {fmt}")
            cs, reader = NUMBERS[fmt]
            return Type(cs, True, lambda r: f"Rd.{reader}(ref {r})", lambda v, d: [f"Wr.Number(w, {v});"])
        if kind == "array":
            only(schema, {"type", "items", "minItems", "maxItems", "default"}, where)
            low, high = schema.get("minItems", 0), schema.get("maxItems", -1)
            items = schema["items"]
            if items.get("format") == "uint8" and items.get("type") == "integer":
                self.type_of(items, where)
                return Type(
                    "byte[]",
                    False,
                    lambda r: f"Rd.Bytes(ref {r}, {low}, {high})",
                    lambda v, d: [f"Wr.Bytes(w, {v}, {low}, {high});"],
                )
            inner = self.type_of(items, f"{where}[]")

            def read(r):
                nested = f"{r}x"
                return f"Rd.List<{inner.cs}>(ref {r}, static (ref Utf8JsonReader {nested}) => {inner.read(nested)}, {low}, {high})"

            def write(value, depth):
                name = f"e{depth}"
                body = inner.write(name, depth + 1)
                return [
                    f"if ({value} is null) throw new ContractJsonException(\"a required array is null\");",
                    f"Wr.ArrayLength({value}.Count, {low}, {high});",
                    "w.WriteStartArray();", f"foreach (var {name} in {value})", "{",
                    *[f"    {line}" for line in body], "}", "w.WriteEndArray();",
                ]

            return Type(f"IReadOnlyList<{inner.cs}>", False, read, write)
        raise Unsupported(f"{where}: unsupported schema {json.dumps(schema)[:120]}")

    def default_of(self, schema, kind, where):
        """The C# expression for a missing optional field, or None for `absent`."""
        if "default" not in schema:
            return "null" if kind.nullable else None
        value = schema["default"]
        if value is None and kind.nullable:
            return "null"
        if value is False and kind.cs == "bool":
            return "false"
        if value == [] and kind.cs == "byte[]":
            return "Array.Empty<byte>()"
        if value == [] and kind.cs.startswith("IReadOnlyList<"):
            return f"Array.Empty<{kind.cs[len('IReadOnlyList<'):-1]}>()"
        if isinstance(value, str) and kind.is_value and kind.cs.startswith(QUALIFIER):
            name = kind.cs[len(QUALIFIER):]
            if value in self.enum_members(name):
                return f"{kind.cs}.{pascal(value)}"
        if isinstance(value, dict) and kind.cs.startswith(QUALIFIER) and not kind.is_value:
            text = literal(json.dumps(value, sort_keys=True, separators=(",", ":")))
            return f"Rd.Default({text}u8, static (ref Utf8JsonReader d) => {kind.read('d')})"
        raise Unsupported(f"{where}: default {json.dumps(value)[:80]} for {kind.cs}")

    def enum_members(self, name):
        members = []
        for variant in self.variants(self.definitions[name], name):
            only(variant, {"enum", "type"}, name)
            if variant.get("type") != "string":
                raise Unsupported(f"{name}: non-string enum")
            members.extend(variant["enum"])
        return members

    # --- emission -------------------------------------------------------

    def fields(self, schema, where, owner):
        only(schema, {"type", "properties", "required", "additionalProperties"}, where)
        if schema.get("additionalProperties", True) not in (True, False):
            raise Unsupported(f"{where}: additionalProperties schema")
        required = set(schema.get("required", []))
        result, seen = [], set()
        for wire, prop in schema.get("properties", {}).items():
            kind = self.type_of(prop, f"{where}.{wire}")
            default = None
            if wire not in required:
                default = self.default_of(prop, kind, f"{where}.{wire}")
                if default is None:
                    kind, default = absent_of(kind), "null"
            name = pascal(wire)
            if name == owner or name in RESERVED_MEMBERS:
                name += "Value"
            if name in seen:
                raise Unsupported(f"{where}: two fields named {name}")
            seen.add(name)
            result.append({"wire": wire, "name": name, "type": kind, "required": wire in required, "default": default, "schema": prop})
        return result, schema.get("additionalProperties", True) is False

    def read_object(self, fields, closed, construct, pad, check=None):
        lines = [f"{pad}Rd.StartObject(ref r);"]
        for index, field in enumerate(fields):
            kind = field["type"]
            declared = kind.cs if kind.is_value or kind.nullable else kind.cs + "?"
            lines.append(f"{pad}{declared} f{index} = default;")
            lines.append(f"{pad}bool h{index} = false;")
        lines += [f"{pad}while (Rd.NextProperty(ref r, out string name))", f"{pad}{{", f"{pad}    switch (name)", f"{pad}    {{"]
        for index, field in enumerate(fields):
            lines += [
                f"{pad}        case {literal(field['wire'])}:",
                f"{pad}            Rd.Once(ref h{index}, name);",
                f"{pad}            f{index} = {field['type'].read('r')};",
                f"{pad}            break;",
            ]
        lines += [f"{pad}        default:", f"{pad}            {'throw Rd.UnknownField(name);' if closed else 'r.Skip();'}"]
        if not closed:
            lines.append(f"{pad}            break;")
        lines += [f"{pad}    }}", f"{pad}}}"]
        arguments = []
        for index, field in enumerate(fields):
            kind = field["type"]
            if field["required"]:
                lines.append(f"{pad}if (!h{index}) throw Rd.MissingField({literal(field['wire'])});")
            elif field["default"] != "null":
                lines.append(f"{pad}if (!h{index}) f{index} = {field['default']};")
            arguments.append(f"{field['name']} = f{index}" + ("" if kind.is_value or kind.nullable else "!"))
        built = f"new {construct} {{ {', '.join(arguments)} }}" if arguments else f"new {construct}()"
        lines.append(f"{pad}return {check}({built});" if check else f"{pad}return {built};")
        return lines

    def write_object(self, fields, pad):
        lines = [f"{pad}w.WriteStartObject();"]
        for field in fields:
            name = literal(field["wire"])
            body = [f"w.WritePropertyName({name});", *field["type"].write(field["name"], 0)]
            if not field["required"] and field["type"].nullable:
                # Rust accepts the omission: the field is not required.
                lines += [f"{pad}if ({field['name']} is not null)", f"{pad}{{", *[f"{pad}    {line}" for line in body], f"{pad}}}"]
            else:
                lines += [f"{pad}{line}" for line in body]
        lines.append(f"{pad}w.WriteEndObject();")
        return lines

    @staticmethod
    def properties(fields, pad):
        """Named members, never positional ones: the schema lists fields in
        alphabetical order, and two strings swapped by position compile."""
        rows = []
        for field in fields:
            rows += summary(field["schema"], pad)
            required = "required " if field["required"] else ""
            initial = "" if field["required"] or field["default"] == "null" else f" = {field['default']};"
            rows += [f"{pad}public {required}{field['type'].cs} {field['name']} {{ get; init; }}{initial}", ""]
        return rows

    def emit_struct(self, name, schema):
        fields, closed = self.fields(schema, name, name)
        check = CHECKED_TYPES.get(name)
        if check:
            self.checked.add(name)
            closed = True
        lines = summary(schema, "    ")
        lines += [f"    public sealed record {name}", "    {", *self.properties(fields, "        ")]
        # A record names itself and nothing more: a payload holds key material
        # or card content, and the ToString C# synthesizes would print it.
        lines += [f"        public override string ToString() => {literal(name)};", ""]
        lines += [f"        internal static {name} Read(ref Utf8JsonReader r)", "        {"]
        lines += self.read_object(fields, closed, name, "            ", check)
        lines += ["        }", "", "        internal void Write(Utf8JsonWriter w)", "        {"]
        lines += self.write_object(fields, "            ")
        lines += ["        }", "    }"]
        return lines

    def emit_enum(self, name, schema):
        members = self.enum_members(name)
        identifiers = [pascal(member) for member in members]
        if len(set(identifiers)) != len(identifiers):
            raise Unsupported(f"{name}: two members share a C# name")
        documented = {}
        for variant in self.variants(schema, name):
            for member in variant["enum"]:
                documented[member] = variant if "oneOf" in schema else {}
        lines = summary(schema, "    ") + [f"    public enum {name}", "    {"]
        for member, identifier in zip(members, identifiers):
            lines += summary(documented[member], "        ")
            lines.append(f"        {identifier},")
        lines += ["    }", "", f"    internal static class {name}Json", "    {"]
        lines += [f"        internal static {name} Read(ref Utf8JsonReader r) => Rd.Name(ref r) switch", "        {"]
        lines += [f"            {literal(member)} => {name}.{identifier}," for member, identifier in zip(members, identifiers)]
        lines += [f"            _ => throw Rd.UnknownVariant({literal(name)}),", "        };", ""]
        lines += [f"        internal static void Write(Utf8JsonWriter w, {name} value) => w.WriteStringValue(value switch", "        {"]
        lines += [f"            {name}.{identifier} => {literal(member)}," for member, identifier in zip(members, identifiers)]
        lines += [f"            _ => throw Rd.UnknownVariant({literal(name)}),", "        });", "    }"]
        return lines

    def emit_union(self, name, schema):
        units, tagged, taken = [], [], set()

        def claim(wire):
            identifier = pascal(wire)
            if identifier == name or identifier in RESERVED_MEMBERS:
                identifier += "Variant"
            if identifier in taken:
                raise Unsupported(f"{name}: two variants named {identifier}")
            taken.add(identifier)
            return identifier

        for variant in self.variants(schema, name):
            if "enum" in variant:
                only(variant, {"enum", "type"}, name)
                if variant.get("type") != "string":
                    raise Unsupported(f"{name}: non-string unit variant")
                units += [(wire, claim(wire), variant) for wire in variant["enum"]]
                continue
            only(variant, {"type", "properties", "required", "additionalProperties"}, name)
            properties = variant.get("properties", {})
            if variant.get("type") != "object" or len(properties) != 1 or variant.get("required") != list(properties):
                raise Unsupported(f"{name}: a variant is not `{{Tag: payload}}`")
            if variant.get("additionalProperties") is not False:
                raise Unsupported(f"{name}: an externally tagged variant must be closed")
            (wire, payload), = properties.items()
            tagged.append((wire, claim(wire), variant, payload))

        lines = summary(schema, "    ") + [f"    public abstract record {name}", "    {"]
        lines += [f"        private protected {name}() {{ }}", ""]
        lines += ["        public sealed override string ToString() => GetType().Name;", "", "        internal abstract void Write(Utf8JsonWriter w);", ""]
        lines += [f"        internal static {name} Read(ref Utf8JsonReader r)", "        {"]
        if units:
            lines += ["            if (r.TokenType == JsonTokenType.String)", "            {", "                return Rd.Name(ref r) switch", "                {"]
            lines += [f"                    {literal(wire)} => new {identifier}()," for wire, identifier, _ in units]
            lines += [f"                    _ => throw Rd.UnknownVariant({literal(name)}),", "                };", "            }"]
        lines += [f"            string tag = Rd.Tag(ref r, {literal(name)});", f"            {name} value = tag switch", "            {"]
        lines += [f"                {literal(wire)} => {identifier}.ReadPayload(ref r)," for wire, identifier, _, _ in tagged]
        lines += [f"                _ => throw Rd.UnknownVariant({literal(name)}),", "            };", f"            Rd.EndTag(ref r, {literal(name)});", "            return value;", "        }"]
        for wire, identifier, variant in units:
            lines += ["", *summary(variant if "oneOf" in schema else {}, "        ")]
            lines += [f"        public sealed record {identifier} : {name}", "        {"]
            lines += [f"            internal override void Write(Utf8JsonWriter w) => w.WriteStringValue({literal(wire)});", "        }"]
        for wire, identifier, variant, payload in tagged:
            lines += ["", *summary(variant, "        ")]
            where = f"{name}.{wire}"
            is_struct = payload.get("type") == "object" and "$ref" not in payload
            if is_struct:
                fields, closed = self.fields(payload, where, identifier)
            else:
                kind = self.type_of(payload, where)
                fields, closed = [{"wire": wire, "name": "Value", "type": kind, "required": True, "default": None, "schema": {}}], True
            if is_struct:
                lines += [f"        public sealed record {identifier} : {name}", "        {", *self.properties(fields, "            ")]
            else:
                lines += [f"        public sealed record {identifier}({fields[0]['type'].cs} Value) : {name}", "        {"]
            lines += [f"            internal static {identifier} ReadPayload(ref Utf8JsonReader r)", "            {"]
            if is_struct:
                lines += self.read_object(fields, closed, identifier, "                ")
            else:
                lines.append(f"                return new {identifier}({fields[0]['type'].read('r')});")
            lines += ["            }", "", "            internal override void Write(Utf8JsonWriter w)", "            {"]
            lines += ["                w.WriteStartObject();", f"                w.WritePropertyName({literal(wire)});"]
            if is_struct:
                lines += self.write_object(fields, "                ")
            else:
                lines += [f"                {line}" for line in fields[0]["type"].write("Value", 0)]
            lines += ["                w.WriteEndObject();", "            }", "        }"]
        lines.append("    }")
        return lines

    def file(self, blocks):
        lines = [
            # The header of the generated file, not this script's: the REUSE
            # linter reads the closing quote as part of a licence expression.
            # REUSE-IgnoreStart
            "// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>",
            "// SPDX-License-Identifier: AGPL-3.0-or-later",
            # REUSE-IgnoreEnd
            "// <auto-generated>scripts/generate-csharp.py from schema/vauchi-contract-v1.json</auto-generated>",
            "#nullable enable",
            "",
            "using System;",
            "using System.Collections.Generic;",
            "using System.Text.Json;",
            "",
            f"namespace {NAMESPACE}",
            "{",
        ]
        for index, block in enumerate(blocks):
            lines += ([""] if index else []) + block
        lines.append("}")
        return "\n".join(line.rstrip() for line in lines) + "\n"

    def generate(self):
        emitters = {"struct": self.emit_struct, "enum": self.emit_enum, "union": self.emit_union}
        types = [emitters[self.kinds[name]](name, self.definitions[name]) for name in sorted(self.definitions)]
        files = {"Types.g.cs": self.file(types)}
        for name, schema in self.roots.items():
            files[f"{name}.g.cs"] = self.file([self.emit_union(name, schema)])
        unused = sorted(set(BEYOND_THE_SCHEMA) - self.refined) + sorted(set(CHECKED_TYPES) - self.checked)
        if unused:
            raise Unsupported(f"rules for fields or types the schema no longer has: {unused}")
        return files


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    schema_path = args.schema or repo / "schema/vauchi-contract-v1.json"
    output = args.output or repo / "csharp/Vauchi.Contract/Generated"
    try:
        files = Generator(json.loads(schema_path.read_text(encoding="utf-8"))).generate()
    except Unsupported as error:
        print(f"C# generation stopped: {error}", file=sys.stderr)
        return 2
    if args.write:
        output.mkdir(parents=True, exist_ok=True)
        for name, text in files.items():
            (output / name).write_text(text, encoding="utf-8", newline="\n")
        for stale in sorted(set(path.name for path in output.glob("*.g.cs")) - set(files)):
            (output / stale).unlink()
        print(f"wrote {len(files)} files to {output}")
        return 0
    stale = [name for name, text in files.items() if not (output / name).is_file() or (output / name).read_text(encoding="utf-8") != text]
    stale += sorted(set(path.name for path in output.glob("*.g.cs")) - set(files))
    if stale:
        print(f"C# contract types are stale: {', '.join(stale)}; run scripts/generate-csharp.py --write", file=sys.stderr)
        return 1
    print("C# generation is current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
