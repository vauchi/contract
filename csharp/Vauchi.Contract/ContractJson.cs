// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Buffers;
using System.Text.Json;

namespace Vauchi.Contract
{
    /// <summary>
    /// A message that is not the contract's JSON. The text names a field or
    /// a type, never a value: payloads carry key material and card content.
    /// </summary>
    public sealed class ContractJsonException : Exception
    {
        public ContractJsonException(string message) : base(message) { }
    }

    /// <summary>
    /// The contract's wire format: what serde writes for the Rust types.
    /// Decoding accepts what the schema allows; the caller bounds the
    /// message size before calling.
    /// </summary>
    public static class ContractJson
    {
        // serde_json's recursion limit.
        private const int MaxDepth = 128;

        public static Command DecodeCommand(ReadOnlySpan<byte> utf8) =>
            Decode(utf8, static (ref Utf8JsonReader r) => Command.Read(ref r));

        public static Event DecodeEvent(ReadOnlySpan<byte> utf8) =>
            Decode(utf8, static (ref Utf8JsonReader r) => Event.Read(ref r));

        public static byte[] EncodeCommand(Command command) => Encode(command.Write);

        public static byte[] EncodeEvent(Event observation) => Encode(observation.Write);

        private static T Decode<T>(ReadOnlySpan<byte> utf8, ReadValue<T> read)
        {
            try
            {
                var reader = new Utf8JsonReader(utf8, new JsonReaderOptions { MaxDepth = MaxDepth });
                if (!reader.Read())
                {
                    throw new ContractJsonException("empty message");
                }
                T value = read(ref reader);
                if (reader.Read())
                {
                    throw new ContractJsonException("trailing content");
                }
                return value;
            }
            catch (Exception error) when (error is JsonException or InvalidOperationException or FormatException)
            {
                throw new ContractJsonException("malformed JSON");
            }
        }

        private static byte[] Encode(Action<Utf8JsonWriter> write)
        {
            var buffer = new ArrayBufferWriter<byte>();
            using (var writer = new Utf8JsonWriter(buffer))
            {
                write(writer);
            }
            return buffer.WrittenSpan.ToArray();
        }
    }

    internal delegate T ReadValue<T>(ref Utf8JsonReader reader);
}
