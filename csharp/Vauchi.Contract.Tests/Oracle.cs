// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Vauchi.Contract.Tests;

/// <summary>
/// What the Rust types did with one message: `scripts/build-swift-oracle.py`
/// runs every case through serde and records acceptance and the value
/// serde writes back.
/// </summary>
public sealed record OracleCase(string Id, string Kind, string Json, bool Accepted, JsonNode? Value)
{
    public override string ToString() => Id;
}

public static class Oracle
{
    /// <summary>
    /// Core's own event boundary adds limits no shell applies; those cases
    /// are Core's.
    /// </summary>
    private const string CoreBoundaryKind = "boundary";

    public static string Checkout
    {
        get
        {
            for (var at = new DirectoryInfo(AppContext.BaseDirectory); at != null; at = at.Parent)
            {
                if (File.Exists(Path.Combine(at.FullName, "schema", "vauchi-contract-v1.json")))
                {
                    return at.FullName;
                }
            }
            throw new InvalidOperationException("no contract checkout above the test binary");
        }
    }

    public static string Directory
    {
        get
        {
            string? configured = Environment.GetEnvironmentVariable("VAUCHI_ORACLE_DIR");
            return string.IsNullOrEmpty(configured) ? Path.Combine(Checkout, "cache", "oracle") : configured;
        }
    }

    public static IReadOnlyList<OracleCase> Load()
    {
        var cases = new List<OracleCase>();
        foreach (string name in new[] { "cases", "corpus", "mutants" })
        {
            var expected = Lines(name, expected: true).ToDictionary(
                line => line["id"]!.GetValue<string>(),
                line => line);
            foreach (JsonNode request in Lines(name, expected: false))
            {
                string id = request["id"]!.GetValue<string>();
                string kind = request["kind"]!.GetValue<string>();
                if (kind == CoreBoundaryKind)
                {
                    continue;
                }
                JsonNode result = expected.TryGetValue(id, out JsonNode? found)
                    ? found
                    : throw new InvalidDataException($"{name}: the oracle has no result for {id}");
                bool accepted = result["ok"]!.GetValue<bool>();
                cases.Add(new OracleCase(
                    id,
                    kind,
                    request["json"]!.GetValue<string>(),
                    accepted,
                    accepted ? result["value"]!.DeepClone() : null));
            }
        }
        return cases;
    }

    private static IEnumerable<JsonNode> Lines(string name, bool expected)
    {
        string path = Path.Combine(Directory, (expected ? "expected-" : "") + name + ".jsonl");
        if (!File.Exists(path))
        {
            throw new FileNotFoundException(
                $"{path} is missing: run `python3 scripts/build-swift-oracle.py` in the contract repository first");
        }
        // Numbers stay text: a u64 above 2^53 must not pass through a double.
        var options = new JsonDocumentOptions { MaxDepth = 256 };
        foreach (string line in File.ReadLines(path, Encoding.UTF8))
        {
            if (line.Length > 0)
            {
                yield return JsonNode.Parse(line, documentOptions: options)!;
            }
        }
    }
}
