// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Nodes;
using Xunit;

namespace Vauchi.Contract.Tests;

public class OracleParityTests
{
    /// <summary>
    /// serde reads a struct from an array of its fields in order, so Rust
    /// takes <c>[]</c> for a struct whose fields all have defaults. The
    /// schema says object, no Rust code writes the array form, and this
    /// product follows the schema.
    /// </summary>
    private static readonly HashSet<string> RustReadsAStructFromAnArray = new()
    {
        "event:HardwareCapabilitiesReported/capabilities:array",
    };

    private static readonly IReadOnlyList<OracleCase> Cases = Oracle.Load()
        .Where(probe => !RustReadsAStructFromAnArray.Contains(probe.Id))
        .ToList();

    private static byte[]? Reencode(OracleCase probe)
    {
        byte[] utf8 = Encoding.UTF8.GetBytes(probe.Json);
        try
        {
            return probe.Kind == "command"
                ? ContractJson.EncodeCommand(ContractJson.DecodeCommand(utf8))
                : ContractJson.EncodeEvent(ContractJson.DecodeEvent(utf8));
        }
        catch (ContractJsonException)
        {
            return null;
        }
    }

    [Fact]
    public void TheOracleCorpusHoldsBothAcceptedAndRejectedMessagesOfBothKinds()
    {
        Assert.Contains(Cases, probe => probe is { Kind: "command", Accepted: true });
        Assert.Contains(Cases, probe => probe is { Kind: "command", Accepted: false });
        Assert.Contains(Cases, probe => probe is { Kind: "event", Accepted: true });
        Assert.Contains(Cases, probe => probe is { Kind: "event", Accepted: false });
        Assert.True(Cases.Count >= 300, $"only {Cases.Count} oracle cases were loaded");
    }

    [Fact]
    public void EveryMessageIsAcceptedOrRejectedAsTheRustTypesDo()
    {
        var disagreements = Cases
            .Where(probe => (Reencode(probe) != null) != probe.Accepted)
            .Select(probe => $"{probe.Id}: Rust {(probe.Accepted ? "accepts" : "rejects")}")
            .ToList();

        Assert.Equal(new List<string>(), disagreements);
    }

    [Fact]
    public void AnAcceptedMessageIsWrittenBackAsTheRustTypesWriteIt()
    {
        var differences = new List<string>();
        foreach (OracleCase probe in Cases.Where(probe => probe.Accepted))
        {
            byte[]? written = Reencode(probe);
            if (written == null)
            {
                continue;
            }
            string? difference = WireJson.Difference(probe.Value!, JsonNode.Parse(written)!, "$");
            if (difference != null)
            {
                differences.Add($"{probe.Id}: {difference}");
            }
        }

        Assert.Equal(new List<string>(), differences);
    }

    [Fact]
    public void WritingAgainWhatWasReadBackChangesNothing()
    {
        foreach (OracleCase probe in Cases.Where(probe => probe.Accepted))
        {
            byte[] once = Reencode(probe)!;
            byte[] twice = Reencode(probe with { Json = Encoding.UTF8.GetString(once) })!;

            Assert.Equal(Encoding.UTF8.GetString(once), Encoding.UTF8.GetString(twice));
        }
    }
}
