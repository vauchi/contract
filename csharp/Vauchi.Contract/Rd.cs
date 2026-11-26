// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Collections.Generic;
using System.Text.Json;

namespace Vauchi.Contract
{
    /// <summary>
    /// Readers the generated code calls with the reader on a value's first
    /// token; each leaves it on the value's last token.
    /// </summary>
    internal static class Rd
    {
        // The name is the sender's text, not the schema's, so it is not repeated.
        internal static ContractJsonException UnknownField(string name) => new("unknown field");

        internal static ContractJsonException MissingField(string name) => new($"missing field {name}");

        internal static ContractJsonException UnknownVariant(string type) => new($"unknown {type} variant");

        internal static void StartObject(ref Utf8JsonReader r)
        {
            if (r.TokenType != JsonTokenType.StartObject)
            {
                throw new ContractJsonException("expected an object");
            }
        }

        internal static bool NextProperty(ref Utf8JsonReader r, out string name)
        {
            r.Read();
            if (r.TokenType == JsonTokenType.EndObject)
            {
                name = "";
                return false;
            }
            name = r.GetString()!;
            r.Read();
            return true;
        }

        internal static void Once(ref bool seen, string name)
        {
            if (seen)
            {
                throw new ContractJsonException($"duplicate field {name}");
            }
            seen = true;
        }

        /// <summary>The tag of <c>{"Tag": payload}</c>, leaving the reader on the payload.</summary>
        internal static string Tag(ref Utf8JsonReader r, string type)
        {
            if (r.TokenType != JsonTokenType.StartObject)
            {
                throw new ContractJsonException($"expected a {type}");
            }
            if (!NextProperty(ref r, out string tag))
            {
                throw new ContractJsonException($"{type} names no variant");
            }
            return tag;
        }

        internal static void EndTag(ref Utf8JsonReader r, string type)
        {
            r.Read();
            if (r.TokenType != JsonTokenType.EndObject)
            {
                throw new ContractJsonException($"{type} names more than one variant");
            }
        }

        internal static string Name(ref Utf8JsonReader r) => String(ref r);

        internal static string String(ref Utf8JsonReader r)
        {
            if (r.TokenType != JsonTokenType.String)
            {
                throw new ContractJsonException("expected a string");
            }
            return r.GetString()!;
        }

        /// <summary>Lengths count UTF-8 bytes, as Rust's <c>str::len</c> does.</summary>
        internal static string String(ref Utf8JsonReader r, int min, int max)
        {
            string value = String(ref r);
            int bytes = System.Text.Encoding.UTF8.GetByteCount(value);
            if (bytes < min || (max >= 0 && bytes > max))
            {
                throw new ContractJsonException("string length out of range");
            }
            return value;
        }

        /// <summary>Rust's <c>char::is_control</c>: the category Cc, all of it below U+0100.</summary>
        internal static string NoControlCharacters(string value)
        {
            foreach (char unit in value)
            {
                if (char.IsControl(unit))
                {
                    throw new ContractJsonException("control character in an identifier");
                }
            }
            return value;
        }

        /// <summary>
        /// Rust's <c>validate_identifier</c> for surface, interaction and
        /// binding ids: 1 to 128 bytes and no control character.
        /// </summary>
        internal static string Identifier(string value)
        {
            int bytes = System.Text.Encoding.UTF8.GetByteCount(value);
            if (bytes < 1 || bytes > 128)
            {
                throw new ContractJsonException("identifier length out of range");
            }
            return NoControlCharacters(value);
        }

        /// <summary>
        /// Rust's <c>QrPlacement::new</c>: the code is at least half the
        /// square's side and lies inside it, in permille.
        /// </summary>
        internal static QrPlacement QrPlacement(QrPlacement placement)
        {
            const int Full = 1000;
            const int MinSize = 500;
            int room = Full - placement.Size;
            if (placement.Size < MinSize || room < 0 || placement.X > room || placement.Y > room)
            {
                throw new ContractJsonException("placement outside its square");
            }
            return placement;
        }

        internal static bool Bool(ref Utf8JsonReader r) => r.TokenType switch
        {
            JsonTokenType.True => true,
            JsonTokenType.False => false,
            _ => throw new ContractJsonException("expected a boolean"),
        };

        internal static byte U8(ref Utf8JsonReader r) => Number(ref r) && r.TryGetByte(out byte v) ? v : throw Range();

        internal static ushort U16(ref Utf8JsonReader r) => Number(ref r) && r.TryGetUInt16(out ushort v) ? v : throw Range();

        internal static uint U32(ref Utf8JsonReader r) => Number(ref r) && r.TryGetUInt32(out uint v) ? v : throw Range();

        internal static ulong U64(ref Utf8JsonReader r) => Number(ref r) && r.TryGetUInt64(out ulong v) ? v : throw Range();

        internal static short I16(ref Utf8JsonReader r) => Signed(ref r) && r.TryGetInt16(out short v) ? v : throw Range();

        internal static int I32(ref Utf8JsonReader r) => Signed(ref r) && r.TryGetInt32(out int v) ? v : throw Range();

        /// <summary>
        /// Read as serde_json does, a double narrowed to f32, so a value
        /// between two floats rounds the same way. A number beyond f32
        /// becomes infinity there, which serde then writes as null; here it
        /// is refused.
        /// </summary>
        internal static float F32(ref Utf8JsonReader r)
        {
            float narrowed = (float)F64(ref r);
            return float.IsFinite(narrowed) ? narrowed : throw Range();
        }

        internal static double F64(ref Utf8JsonReader r) =>
            Number(ref r) && r.TryGetDouble(out double v) && double.IsFinite(v) ? v : throw Range();

        private static bool Number(ref Utf8JsonReader r) =>
            r.TokenType == JsonTokenType.Number ? true : throw new ContractJsonException("expected a number");

        /// <summary>
        /// serde_json reads <c>-0</c> as the float -0.0 and refuses it for
        /// an integer; .NET reads it as the integer 0.
        /// </summary>
        private static bool Signed(ref Utf8JsonReader r) =>
            Number(ref r) && !r.ValueSpan.SequenceEqual("-0"u8);

        private static ContractJsonException Range() => new("number out of range");

        internal static byte[] Bytes(ref Utf8JsonReader r, int min, int max)
        {
            StartArray(ref r);
            var bytes = new List<byte>(max >= 0 ? max : 16);
            while (NextItem(ref r))
            {
                bytes.Add(U8(ref r));
                CheckMax(bytes.Count, max);
            }
            CheckMin(bytes.Count, min);
            return bytes.ToArray();
        }

        internal static IReadOnlyList<T> List<T>(ref Utf8JsonReader r, ReadValue<T> read, int min, int max)
        {
            StartArray(ref r);
            var items = new List<T>();
            while (NextItem(ref r))
            {
                items.Add(read(ref r));
                CheckMax(items.Count, max);
            }
            CheckMin(items.Count, min);
            return items;
        }

        /// <summary>A default the schema states as JSON, read the way a sent value is.</summary>
        internal static T Default<T>(ReadOnlySpan<byte> json, ReadValue<T> read)
        {
            var reader = new Utf8JsonReader(json);
            reader.Read();
            return read(ref reader);
        }

        private static void StartArray(ref Utf8JsonReader r)
        {
            if (r.TokenType != JsonTokenType.StartArray)
            {
                throw new ContractJsonException("expected an array");
            }
        }

        private static bool NextItem(ref Utf8JsonReader r)
        {
            r.Read();
            return r.TokenType != JsonTokenType.EndArray;
        }

        private static void CheckMax(int count, int max)
        {
            if (max >= 0 && count > max)
            {
                throw new ContractJsonException("array too long");
            }
        }

        private static void CheckMin(int count, int min)
        {
            if (count < min)
            {
                throw new ContractJsonException("array too short");
            }
        }
    }

    internal static class Wr
    {
        internal static void ArrayLength(int count, int minimum, int maximum)
        {
            if (count < minimum || (maximum >= 0 && count > maximum))
            {
                throw new ContractJsonException("array length outside schema bounds");
            }
        }

        internal static void Bytes(Utf8JsonWriter w, byte[] bytes, int minimum, int maximum)
        {
            if (bytes is null)
            {
                throw new ContractJsonException("a required array is null");
            }
            ArrayLength(bytes.Length, minimum, maximum);
            w.WriteStartArray();
            foreach (byte value in bytes)
            {
                w.WriteNumberValue(value);
            }
            w.WriteEndArray();
        }

        internal static void Number(Utf8JsonWriter w, double value)
        {
            if (!double.IsFinite(value))
            {
                throw new ContractJsonException("a number that JSON cannot carry");
            }
            w.WriteNumberValue(value);
        }

        internal static void Number(Utf8JsonWriter w, float value)
        {
            if (!float.IsFinite(value))
            {
                throw new ContractJsonException("a number that JSON cannot carry");
            }
            w.WriteNumberValue(value);
        }
    }
}
