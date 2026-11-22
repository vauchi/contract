// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace Vauchi.Contract.Tests;

/// <summary>
/// The fixture every shell replays (<c>tests/protocol_conformance.rs</c> is
/// the Rust reading of it).
/// </summary>
public class ProtocolConformanceTests
{
    private static readonly JsonNode Fixture = JsonNode.Parse(
        File.ReadAllText(Path.Combine(Oracle.Checkout, "fixtures", "protocol_conformance_v1.json"), Encoding.UTF8))!;

    private static IEnumerable<JsonNode> Entries(string section) =>
        Fixture[section]!.AsArray().Select(entry => entry!);

    private static byte[] Utf8(JsonNode entry) => Encoding.UTF8.GetBytes(entry.ToJsonString());

    private static void AssertWrittenBackUnchanged(JsonNode entry, byte[] written) =>
        Assert.Null(WireJson.Difference(entry, JsonNode.Parse(written)!, "$"));

    [Fact]
    public void TheFixtureHoldsTheSectionsThisReplayReads()
    {
        Assert.Equal(1, Fixture["schema_version"]!.GetValue<int>());
        Assert.Single(Entries("nodes"));
        Assert.Equal(2, Entries("commands").Count());
        Assert.Equal(3, Entries("events").Count());
        Assert.Equal(2, Entries("invalid_events").Count());
    }

    [Fact]
    public void EveryCommandIsReadAndWrittenBackUnchanged()
    {
        foreach (JsonNode entry in Entries("commands"))
        {
            AssertWrittenBackUnchanged(entry, ContractJson.EncodeCommand(ContractJson.DecodeCommand(Utf8(entry))));
        }
    }

    [Fact]
    public void EveryEventIsReadAndWrittenBackUnchanged()
    {
        foreach (JsonNode entry in Entries("events"))
        {
            AssertWrittenBackUnchanged(entry, ContractJson.EncodeEvent(ContractJson.DecodeEvent(Utf8(entry))));
        }
    }

    [Fact]
    public void EveryPresentationNodeIsReadAndWrittenBackUnchanged()
    {
        foreach (JsonNode entry in Entries("nodes"))
        {
            var reader = new Utf8JsonReader(Utf8(entry));
            reader.Read();
            PresentationNode node = PresentationNode.Read(ref reader);

            using var buffer = new MemoryStream();
            using (var writer = new Utf8JsonWriter(buffer))
            {
                node.Write(writer);
            }
            AssertWrittenBackUnchanged(entry, buffer.ToArray());
        }
    }

    [Fact]
    public void EveryInvalidEventIsRefused()
    {
        foreach (JsonNode entry in Entries("invalid_events"))
        {
            byte[] utf8 = Utf8(entry);
            Assert.Throws<ContractJsonException>(() => ContractJson.DecodeEvent(utf8));
        }
    }

    [Fact]
    public void TheCommandsOfTheFixtureDecodeToTheirNamedVariants()
    {
        var write = Assert.IsType<Command.BleWriteCharacteristic>(
            ContractJson.DecodeCommand(Utf8(Entries("commands").First())));

        Assert.Equal("opaque.peer", write.DeviceId);
        Assert.Equal(BleLinkDirection.Outbound, write.Direction);
        Assert.Equal("00000000-0000-0000-0000-000000000001", write.Uuid);
        Assert.Equal(new byte[] { 1, 2, 3 }, write.Data);
    }

    [Fact]
    public void ARefusalNamesNoPartOfTheMessage()
    {
        byte[] utf8 = Encoding.UTF8.GetBytes("{\"HardwareError\":{\"transport\":\"secret-transport\",\"oops\":1}}");

        var refusal = Assert.Throws<ContractJsonException>(() => ContractJson.DecodeEvent(utf8));

        Assert.DoesNotContain("secret-transport", refusal.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("oops", refusal.Message, StringComparison.Ordinal);
    }
}
