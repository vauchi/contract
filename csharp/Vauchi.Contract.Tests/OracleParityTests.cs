// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace Vauchi.Contract.Tests;

public class OracleParityTests
{
    /// <summary>
    /// serde reads forms the schema does not have and no Rust code writes:
    /// every struct from an array of its fields in order, a unit variant
    /// from <c>{"Name": null}</c>, a number beyond f32 as infinity. This
    /// product follows the schema and refuses them. The changed-message
    /// set meets one such form, <c>[]</c> for a struct whose fields all
    /// have defaults.
    /// </summary>
    private static readonly HashSet<string> RustReadsAStructFromAnArray = new()
    {
        "event:HardwareCapabilitiesReported/capabilities:array",
    };

    private static readonly IReadOnlyList<OracleCase> Everything = Oracle.Load();

    private static readonly IReadOnlyList<OracleCase> Cases = Everything
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
    public void EveryExceptionIsAMessageRustAcceptsAndThisProductRefuses()
    {
        foreach (string id in RustReadsAStructFromAnArray)
        {
            OracleCase probe = Assert.Single(Everything, found => found.Id == id);

            Assert.True(probe.Accepted, $"{id}: Rust no longer accepts it; drop the exception");
            Assert.Null(Reencode(probe));
        }
    }

    [Theory]
    [InlineData(":raw_-0")]
    [InlineData(":raw_-0.0")]
    [InlineData(":raw_1e400")]
    [InlineData(":raw_NaN")]
    [InlineData(":items_1")]
    [InlineData(":nested_127")]
    [InlineData(":nested_128")]
    [InlineData(":placement_1000_1_0")]
    public void TheChangedMessagesHoldTheProbesThatFoundDifferences(string label)
    {
        Assert.Contains(Everything, probe => probe.Id.EndsWith(label, System.StringComparison.Ordinal));
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
            // The nesting probes are deeper than the parser's default of 64.
            JsonNode rewritten = JsonNode.Parse(written, documentOptions: new JsonDocumentOptions { MaxDepth = 256 })!;
            string? difference = WireJson.Difference(probe.Value!, rewritten, "$");
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
