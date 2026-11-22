// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Buffers.Binary;
using System.IO;

namespace Vauchi.Contract
{
    public enum DirectFrameError
    {
        InvalidMagic,
        UnsupportedVersion,
        PayloadTooLarge,
        EmptyPayload,

        /// <summary>The link ended inside a frame.</summary>
        Truncated,
    }

    /// <summary>
    /// A frame that is not the contract's. The text names the rule, never a
    /// byte of the frame: the payload is key material or an encrypted card.
    /// </summary>
    public sealed class DirectFrameException : Exception
    {
        internal DirectFrameException(DirectFrameError error, string message) : base(message) => Error = error;

        public DirectFrameError Error { get; }
    }

    /// <summary>
    /// The frame a <c>DirectSend</c> payload travels in over a wired or
    /// local link: <c>src/direct.rs</c> in C#. A frame is the magic
    /// <c>VXCH</c>, version 1, the payload's length as four big-endian
    /// bytes, then the payload. Both sides exchange one frame each: the
    /// initiator writes first, the responder reads first, so neither waits
    /// on the other. A failure of the link itself surfaces as the stream's
    /// own exception.
    /// </summary>
    public static class DirectFrame
    {
        /// <summary>
        /// The largest payload a frame carries. Exchange payloads are about
        /// 300 bytes; the bound is checked before any payload byte is read.
        /// </summary>
        public const int MaxPayload = 65_536;

        private const byte Version = 1;
        private const int HeaderLength = 9;

        private static ReadOnlySpan<byte> Magic => "VXCH"u8;

        /// <summary>Writes <paramref name="payload"/> as one frame and flushes.</summary>
        public static void Write(Stream link, ReadOnlySpan<byte> payload)
        {
            ArgumentNullException.ThrowIfNull(link);
            if (payload.IsEmpty)
            {
                throw new DirectFrameException(DirectFrameError.EmptyPayload, "empty payload");
            }
            if (payload.Length > MaxPayload)
            {
                throw new DirectFrameException(DirectFrameError.PayloadTooLarge, "payload too large");
            }
            Span<byte> header = stackalloc byte[HeaderLength];
            Magic.CopyTo(header);
            header[4] = Version;
            BinaryPrimitives.WriteUInt32BigEndian(header[5..], (uint)payload.Length);
            link.Write(header);
            link.Write(payload);
            link.Flush();
        }

        /// <summary>Reads one frame and returns its payload, never an empty one.</summary>
        public static byte[] Read(Stream link)
        {
            ArgumentNullException.ThrowIfNull(link);
            Span<byte> header = stackalloc byte[HeaderLength];
            Fill(link, header[..4]);
            if (!header[..4].SequenceEqual(Magic))
            {
                throw new DirectFrameException(DirectFrameError.InvalidMagic, "invalid frame magic");
            }
            Fill(link, header[4..5]);
            if (header[4] != Version)
            {
                throw new DirectFrameException(DirectFrameError.UnsupportedVersion, "unsupported frame version");
            }
            Fill(link, header[5..]);
            uint length = BinaryPrimitives.ReadUInt32BigEndian(header[5..]);
            if (length == 0)
            {
                throw new DirectFrameException(DirectFrameError.EmptyPayload, "empty payload");
            }
            if (length > MaxPayload)
            {
                throw new DirectFrameException(DirectFrameError.PayloadTooLarge, "payload too large");
            }
            var payload = new byte[length];
            Fill(link, payload);
            return payload;
        }

        /// <summary>Sends <paramref name="ours"/> and returns the peer's payload, in the order the role sets.</summary>
        public static byte[] Exchange(Stream link, ReadOnlySpan<byte> ours, bool isInitiator)
        {
            if (isInitiator)
            {
                Write(link, ours);
                return Read(link);
            }
            byte[] theirs = Read(link);
            Write(link, ours);
            return theirs;
        }

        private static void Fill(Stream link, Span<byte> buffer)
        {
            try
            {
                link.ReadExactly(buffer);
            }
            catch (EndOfStreamException)
            {
                throw new DirectFrameException(DirectFrameError.Truncated, "frame ended early");
            }
        }
    }
}
