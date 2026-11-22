// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Vauchi.Contract.Tests;

public static class WireJson
{
    /// <summary>
    /// The first place <paramref name="written"/> differs from what Rust
    /// wrote, or null. One difference is allowed: C# leaves out an optional
    /// member whose value is null, and serde writes `null` for it. Rust
    /// reads both the same way, since the member is not required.
    /// </summary>
    public static string? Difference(JsonNode? rust, JsonNode? written, string path)
    {
        if (rust is JsonObject rustObject && written is JsonObject writtenObject)
        {
            foreach (var member in rustObject)
            {
                if (!writtenObject.TryGetPropertyValue(member.Key, out JsonNode? other))
                {
                    if (member.Value is null)
                    {
                        continue;
                    }
                    return $"{path}.{member.Key} is missing";
                }
                string? nested = Difference(member.Value, other, $"{path}.{member.Key}");
                if (nested != null)
                {
                    return nested;
                }
            }
            string? extra = writtenObject.Select(member => member.Key).FirstOrDefault(key => !rustObject.ContainsKey(key));
            return extra == null ? null : $"{path}.{extra} is not in what Rust wrote";
        }
        if (rust is JsonArray rustArray && written is JsonArray writtenArray)
        {
            if (rustArray.Count != writtenArray.Count)
            {
                return $"{path} has {writtenArray.Count} items, Rust wrote {rustArray.Count}";
            }
            for (int index = 0; index < rustArray.Count; index++)
            {
                string? nested = Difference(rustArray[index], writtenArray[index], $"{path}[{index}]");
                if (nested != null)
                {
                    return nested;
                }
            }
            return null;
        }
        if (rust is null || written is null)
        {
            return rust is null && written is null ? null : $"{path}: one side is null";
        }
        if (rust.GetValueKind() != written.GetValueKind())
        {
            return $"{path}: {written.GetValueKind()} where Rust wrote {rust.GetValueKind()}";
        }
        return SameScalar(rust, written) ? null : $"{path}: a different value";
    }

    private static bool SameScalar(JsonNode rust, JsonNode written)
    {
        if (rust.GetValueKind() != JsonValueKind.Number)
        {
            return JsonNode.DeepEquals(rust, written);
        }
        string left = rust.ToJsonString(), right = written.ToJsonString();
        if (left == right)
        {
            return true;
        }
        // Integers beyond a double's precision must match as text.
        if (left.All(char.IsAsciiDigit) && right.All(char.IsAsciiDigit))
        {
            return false;
        }
        // The oracle answers through `serde_json::to_value`, which widens an
        // f32 to f64: Rust's 0.8f32 arrives as 0.800000011920929 where the
        // wire carries 0.8. Two spellings are the same number when they are
        // the same f32.
        var culture = System.Globalization.CultureInfo.InvariantCulture;
        double rustNumber = double.Parse(left, culture), writtenNumber = double.Parse(right, culture);
        return rustNumber == writtenNumber || (float)rustNumber == (float)writtenNumber;
    }
}
