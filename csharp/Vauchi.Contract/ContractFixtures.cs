// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.IO;

namespace Vauchi.Contract
{
    /// <summary>
    /// The contract's fixtures as this version of the library was built
    /// with them: what <c>vauchi_contract::fixtures</c> is to a Rust shell.
    /// </summary>
    public static class ContractFixtures
    {
        /// <summary>
        /// <c>fixtures/protocol_conformance_v1.json</c> as UTF-8: focused
        /// examples of commands, events and events that must be refused.
        /// </summary>
        public static byte[] ProtocolConformance() => Read("protocol_conformance_v1.json");

        private static byte[] Read(string name)
        {
            using Stream stored = typeof(ContractFixtures).Assembly.GetManifestResourceStream(name)
                ?? throw new InvalidOperationException($"the library was built without {name}");
            using var copy = new MemoryStream();
            stored.CopyTo(copy);
            return copy.ToArray();
        }
    }
}
