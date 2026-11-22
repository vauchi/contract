// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.IO;
using System.Linq;
using Xunit;

namespace Vauchi.Contract.Tests;

/// <summary>
/// The frame of <c>src/direct.rs</c>: <c>VXCH</c>, version 1, the length as
/// four big-endian bytes, the payload.
/// </summary>
public class DirectFrameTests
{
    private static readonly byte[] Header = { (byte)'V', (byte)'X', (byte)'C', (byte)'H', 1 };

    private static byte[] Frame(uint length, params byte[] payload) =>
        Header
            .Concat(new[] { (byte)(length >> 24), (byte)(length >> 16), (byte)(length >> 8), (byte)length })
            .Concat(payload)
            .ToArray();

    private static DirectFrameError Refusal(Action act) => Assert.Throws<DirectFrameException>(act).Error;

    [Fact]
    public void AFrameIsTheMagicTheVersionTheBigEndianLengthAndThePayload()
    {
        using var link = new MemoryStream();

        DirectFrame.Write(link, new byte[] { 0xAA, 0xBB, 0xCC });

        Assert.Equal(
            new byte[] { 0x56, 0x58, 0x43, 0x48, 0x01, 0x00, 0x00, 0x00, 0x03, 0xAA, 0xBB, 0xCC },
            link.ToArray());
    }

    [Fact]
    public void ALengthAboveOneByteIsWrittenBigEndian()
    {
        using var link = new MemoryStream();

        DirectFrame.Write(link, new byte[0x0102]);

        Assert.Equal(new byte[] { 0x00, 0x00, 0x01, 0x02 }, link.ToArray()[5..9]);
    }

    [Fact]
    public void AReadFrameReturnsItsPayloadAndLeavesWhatFollowsUnread()
    {
        byte[] bytes = Frame(2, 7, 8).Concat(new byte[] { 99 }).ToArray();
        using var link = new MemoryStream(bytes);

        byte[] payload = DirectFrame.Read(link);

        Assert.Equal(new byte[] { 7, 8 }, payload);
        Assert.Equal(99, link.ReadByte());
    }

    [Theory]
    [InlineData(1)]
    [InlineData(300)]
    [InlineData(DirectFrame.MaxPayload)]
    public void APayloadUpToTheBoundIsReadBackAsWritten(int length)
    {
        var payload = new byte[length];
        new Random(length).NextBytes(payload);
        using var link = new MemoryStream();

        DirectFrame.Write(link, payload);
        link.Position = 0;

        Assert.Equal(payload, DirectFrame.Read(link));
    }

    [Fact]
    public void PayloadsOfArbitraryLengthAndContentAreReadBackAsWritten()
    {
        var random = new Random(772);
        for (int round = 0; round < 500; round++)
        {
            var payload = new byte[random.Next(1, 2049)];
            random.NextBytes(payload);
            using var link = new MemoryStream();

            DirectFrame.Write(link, payload);
            link.Position = 0;

            Assert.Equal(payload, DirectFrame.Read(link));
        }
    }

    [Fact]
    public void AnEmptyPayloadIsNotWritten()
    {
        using var link = new MemoryStream();

        Assert.Equal(DirectFrameError.EmptyPayload, Refusal(() => DirectFrame.Write(link, ReadOnlySpan<byte>.Empty)));
        Assert.Equal(0, link.Length);
    }

    [Fact]
    public void APayloadAboveTheBoundIsNotWritten()
    {
        using var link = new MemoryStream();
        var payload = new byte[DirectFrame.MaxPayload + 1];

        Assert.Equal(DirectFrameError.PayloadTooLarge, Refusal(() => DirectFrame.Write(link, payload)));
        Assert.Equal(0, link.Length);
    }

    [Fact]
    public void AnotherMagicIsRefused()
    {
        byte[] bytes = Frame(1, 5);
        bytes[3] = (byte)'X';
        using var link = new MemoryStream(bytes);

        Assert.Equal(DirectFrameError.InvalidMagic, Refusal(() => DirectFrame.Read(link)));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(2)]
    [InlineData(255)]
    public void AnotherVersionIsRefused(byte version)
    {
        byte[] bytes = Frame(1, 5);
        bytes[4] = version;
        using var link = new MemoryStream(bytes);

        Assert.Equal(DirectFrameError.UnsupportedVersion, Refusal(() => DirectFrame.Read(link)));
    }

    [Fact]
    public void ALengthOfZeroIsRefused()
    {
        using var link = new MemoryStream(Frame(0));

        Assert.Equal(DirectFrameError.EmptyPayload, Refusal(() => DirectFrame.Read(link)));
    }

    [Theory]
    [InlineData((uint)DirectFrame.MaxPayload + 1)]
    [InlineData(0x7FFFFFFFu)]
    [InlineData(0x80000000u)]
    [InlineData(0xFFFFFFFFu)]
    public void ALengthAboveTheBoundIsRefusedBeforeAnyPayloadByteIsRead(uint length)
    {
        using var link = new MemoryStream(Frame(length, 1, 2, 3));

        Assert.Equal(DirectFrameError.PayloadTooLarge, Refusal(() => DirectFrame.Read(link)));
        Assert.Equal(9, link.Position);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(8)]
    [InlineData(10)]
    public void AFrameThatEndsEarlyIsRefused(int kept)
    {
        byte[] bytes = Frame(3, 1, 2, 3)[..kept];
        using var link = new MemoryStream(bytes);

        Assert.Equal(DirectFrameError.Truncated, Refusal(() => DirectFrame.Read(link)));
    }

    [Fact]
    public void TheInitiatorWritesFirstAndTheResponderReadsFirst()
    {
        using var toResponder = new MemoryStream();
        using var toInitiator = new MemoryStream();
        DirectFrame.Write(toInitiator, new byte[] { 2, 2 });
        toInitiator.Position = 0;
        using var initiatorLink = new TwoWay(read: toInitiator, write: toResponder);

        byte[] theirs = DirectFrame.Exchange(initiatorLink, new byte[] { 1 }, isInitiator: true);

        Assert.Equal(new byte[] { 2, 2 }, theirs);
        Assert.Equal(Frame(1, 1), toResponder.ToArray());
    }

    [Fact]
    public void TheResponderWritesNothingWhenThePeersFrameIsRefused()
    {
        using var fromPeer = new MemoryStream(Frame(0));
        using var toPeer = new MemoryStream();
        using var link = new TwoWay(read: fromPeer, write: toPeer);

        Assert.Equal(
            DirectFrameError.EmptyPayload,
            Refusal(() => DirectFrame.Exchange(link, new byte[] { 1 }, isInitiator: false)));
        Assert.Equal(0, toPeer.Length);
    }

    [Fact]
    public void ARefusalNamesNoPayloadByte()
    {
        byte[] bytes = Frame(1, 5);
        bytes[4] = 77;
        using var link = new MemoryStream(bytes);

        var refusal = Assert.Throws<DirectFrameException>(() => DirectFrame.Read(link));

        Assert.Equal("unsupported frame version", refusal.Message);
    }

    /// <summary>A link whose two directions are separate streams.</summary>
    private sealed class TwoWay(Stream read, Stream write) : Stream
    {
        public override bool CanRead => true;

        public override bool CanSeek => false;

        public override bool CanWrite => true;

        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override void Flush() => write.Flush();

        public override int Read(byte[] buffer, int offset, int count) => read.Read(buffer, offset, count);

        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();

        public override void SetLength(long value) => throw new NotSupportedException();

        public override void Write(byte[] buffer, int offset, int count) => write.Write(buffer, offset, count);
    }
}
