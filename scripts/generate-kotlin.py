#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Generate Kotlin contract values from the committed Rust-derived schema."""

import argparse
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PACKAGE = "app.vauchi.contract"
PRIMITIVES = {
    "uint8": "UByte", "uint16": "UShort", "uint32": "UInt",
    "uint64": "ULong", "uint": "ULong", "int16": "Short", "int32": "Int",
    "float": "Float", "double": "Double",
}

# Keep the accepted schema subset and the beyond-schema rules shared with
# the existing backend. This is generation-time validation, never a C# or
# Core dependency in the emitted Kotlin library.
spec = importlib.util.spec_from_file_location("contract_schema_reference", Path(__file__).with_name("generate-csharp.py"))
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)

codec_spec = importlib.util.spec_from_file_location("kotlin_codec", Path(__file__).with_name("kotlin-codec.py"))
codec = importlib.util.module_from_spec(codec_spec)
codec_spec.loader.exec_module(codec)


def nullable(name):
    return name if name.endswith("?") else name + "?"


def literal(value):
    quoted = json.dumps(value, ensure_ascii=True).replace("$", "\\$")
    if len(quoted) > 100:
        chunks = [json.dumps(value[index:index + 16], ensure_ascii=True).replace("$", "\\$") for index in range(0, len(value), 16)]
        return "(" + " +\n".join(chunks) + ")"
    return quoted


def property_name(wire):
    name = reference.pascal(wire)
    return name[0].lower() + name[1:]


def formatted(root, files):
    with tempfile.TemporaryDirectory(prefix="vauchi-kotlin-") as directory:
        Path(directory, ".editorconfig").write_text((root / "kotlin/.editorconfig").read_text(encoding="utf-8"), encoding="utf-8")
        for name, text in files.items():
            Path(directory, name).write_text(text, encoding="utf-8")
        command = [str(root / "kotlin/gradlew"), "-p", str(root / "kotlin"), "formatGenerated",
                   "--quiet", f"-PgeneratedRoot={directory}"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=180, check=False)
        changed = any(Path(directory, name).read_text(encoding="utf-8") != text for name, text in files.items())
        # ktlint can report a long line before another rule has wrapped it.
        # Recheck only after the formatter actually changed the source.
        if result.returncode and changed:
            result = subprocess.run(command, capture_output=True, text=True, timeout=180, check=False)
        if result.returncode:
            context = [line for name in files for line in Path(directory, name).read_text(encoding="utf-8").splitlines() if len(line) > 140]
            raise reference.Unsupported("Kotlin formatting failed: " + result.stdout[-2500:] + "\n".join(context) + result.stderr[-1200:])
        return {name: Path(directory, name).read_text(encoding="utf-8") for name in files}


class Generator:
    def __init__(self, schema, version):
        self.model = reference.Generator(schema)
        self.model.generate()
        self.version = version

    def type_of(self, schema):
        if "$ref" in schema:
            return PACKAGE + "." + schema["$ref"].removeprefix("#/definitions/")
        if "allOf" in schema:
            return self.type_of(schema["allOf"][0])
        if "anyOf" in schema:
            base = next(item for item in schema["anyOf"] if item != {"type": "null"})
            return nullable(self.type_of(base))
        kind = schema["type"]
        if isinstance(kind, list):
            return nullable(self.type_of(dict(schema, type=next(item for item in kind if item != "null"))))
        if kind == "array":
            return f"kotlin.collections.List<{self.type_of(schema['items'])}>"
        if kind in ("integer", "number"):
            return "kotlin." + PRIMITIVES[schema["format"]]
        return {"string": "kotlin.String", "boolean": "kotlin.Boolean"}[kind]

    def fields(self, schema):
        required = set(schema.get("required", []))
        fields = []
        seen = set()
        for wire, prop in schema.get("properties", {}).items():
            name = property_name(wire)
            if name in seen:
                raise reference.Unsupported(f"two Kotlin fields named {name}")
            seen.add(name)
            kind = self.type_of(prop)
            if wire not in required and "default" not in prop:
                kind = nullable(kind)
            fields.append((name, kind))
        return fields

    @staticmethod
    def record(name, fields, parent=None, indent=""):
        suffix = f" : {parent}" if parent else ""
        if not fields:
            return [f"{indent}data object {name}{suffix}"]
        return [
            f"{indent}data class {name}(",
            *[f"{indent}    val `{field}`: {kind}," for field, kind in fields],
            f"{indent}){suffix} {{",
            f"{indent}    override fun toString(): kotlin.String = {literal(name)}",
            f"{indent}}}",
        ]

    def emit_union(self, name, schema):
        lines = [f"sealed interface {name} {{"]
        for variant in self.model.variants(schema, name):
            if "enum" in variant:
                for wire in variant["enum"]:
                    lines.extend(self.record(reference.pascal(wire), [], name, "    "))
            else:
                wire, payload = next(iter(variant["properties"].items()))
                fields = self.fields(payload) if payload.get("type") == "object" else [("value", self.type_of(payload))]
                lines.extend(self.record(reference.pascal(wire), fields, name, "    "))
            lines.append("")
        return lines[:-1] + ["}"]

    def emit_enum(self, name, schema):
        members = self.model.enum_members(name)
        return [
            f"enum class {name}(val wireValue: kotlin.String) {{",
            *[f"    {reference.pascal(wire)}({literal(wire)})," for wire in members],
            "}",
        ]

    @staticmethod
    def file(blocks):
        # REUSE-IgnoreStart
        lines = [
            "// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>",
            "// SPDX-License-Identifier: AGPL-3.0-or-later",
            "// Generated by scripts/generate-kotlin.py; edit the schema, not this file.",
            "",
            f"package {PACKAGE}",
        ]
        # REUSE-IgnoreEnd
        for block in blocks:
            lines.extend(["", *block])
        return "\n".join(lines) + "\n"

    def generate(self):
        blocks = []
        for name, schema in sorted(self.model.definitions.items()):
            kind = self.model.kinds[name]
            if kind == "struct":
                block = self.record(name, self.fields(schema))
            elif kind == "enum":
                block = self.emit_enum(name, schema)
            else:
                block = self.emit_union(name, schema)
            blocks.append(block)
        result = {"Types.g.kt": self.file(blocks)}
        for name, schema in self.model.roots.items():
            result[f"{name}.g.kt"] = self.file([self.emit_union(name, schema)])
        result.update(codec.Codec(self, reference, literal, property_name).generate())
        result["ContractInfo.g.kt"] = self.file([[
            "object ContractInfo {",
            f"    const val VERSION: kotlin.String = {literal(self.version)}",
            "",
            "    fun protocolConformanceV1(): kotlin.String =",
            '        ContractInfo::class.java.getResourceAsStream("/app/vauchi/contract/protocol_conformance_v1.json")',
            "            ?.bufferedReader(kotlin.text.Charsets.UTF_8)?.use { it.readText() }",
            '            ?: error("contract replay resource is missing")',
            "}",
        ]])
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = args.schema or root / "schema/vauchi-contract-v1.json"
    output = args.output or root / "kotlin/src/main/kotlin/app/vauchi/contract/generated"
    try:
        version = re.search(r'(?m)^version\s*=\s*"([^"]+)"', (root / "Cargo.toml").read_text(encoding="utf-8"))
        if version is None:
            raise reference.Unsupported("Cargo.toml has no package version")
        files = formatted(root, Generator(json.loads(source.read_text(encoding="utf-8")), version.group(1)).generate())
    except reference.Unsupported as error:
        print(f"Kotlin generation stopped: {error}", file=sys.stderr)
        return 2
    if args.write:
        output.mkdir(parents=True, exist_ok=True)
        for name, text in files.items():
            (output / name).write_text(text, encoding="utf-8", newline="\n")
        for stale in sorted(set(path.name for path in output.glob("*.g.kt")) - set(files)):
            (output / stale).unlink()
        print(f"wrote {len(files)} Kotlin files")
        return 0
    stale = [name for name, text in files.items() if not (output / name).is_file() or (output / name).read_text(encoding="utf-8") != text]
    stale.extend(sorted(set(path.name for path in output.glob("*.g.kt")) - set(files)))
    if stale:
        print(f"Kotlin contract types are stale: {', '.join(stale)}; run scripts/generate-kotlin.py --write", file=sys.stderr)
        return 1
    print("Kotlin generation is current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
