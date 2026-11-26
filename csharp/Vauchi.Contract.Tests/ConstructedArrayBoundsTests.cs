// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Collections.Generic;
using System.Linq;
using Xunit;

namespace Vauchi.Contract.Tests;

public class ConstructedArrayBoundsTests
{
    private static Event Advertisement(IReadOnlyList<BleServiceUuid> services) =>
        new Event.BleAdvertisementObserved(new BleAdvertisementObservation
        {
            Id = "native-id",
            Rssi = -42,
            ServiceUuids = services,
        });

    [Theory]
    [InlineData(15)]
    [InlineData(17)]
    public void Constructed128BitUuidsMustHaveExactly16Bytes(int count)
    {
        var value = Advertisement(new[] { new BleServiceUuid.Uuid128(new byte[count]) });

        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(value));

        Assert.Equal("array length outside schema bounds", error.Message);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(3)]
    public void Constructed16BitUuidsMustHaveExactlyTwoBytes(int count)
    {
        var value = Advertisement(new[] { new BleServiceUuid.Uuid16(new byte[count]) });

        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(value));

        Assert.Equal("array length outside schema bounds", error.Message);
    }

    [Theory]
    [InlineData(3)]
    [InlineData(5)]
    public void Constructed32BitUuidsMustHaveExactlyFourBytes(int count)
    {
        var value = Advertisement(new[] { new BleServiceUuid.Uuid32(new byte[count]) });

        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(value));

        Assert.Equal("array length outside schema bounds", error.Message);
    }

    [Fact]
    public void AConstructedObservationCannotWriteMoreThan32ServiceUuids()
    {
        var services = Enumerable.Range(0, 33).Select(_ => new BleServiceUuid.Uuid128(new byte[16])).ToArray();

        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(Advertisement(services)));

        Assert.Equal("array length outside schema bounds", error.Message);
    }

    [Fact]
    public void ARequiredByteArrayCannotBeNullInAConstructedValue()
    {
        var value = Advertisement(new[] { new BleServiceUuid.Uuid128(null!) });

        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(value));

        Assert.Equal("a required array is null", error.Message);
    }

    [Fact]
    public void ARequiredListCannotBeNullInAConstructedValue()
    {
        var error = Assert.Throws<ContractJsonException>(() => ContractJson.EncodeEvent(Advertisement(null!)));

        Assert.Equal("a required array is null", error.Message);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(32)]
    public void ExactCollectionBoundsAndUuidWidthsStillRoundTrip(int count)
    {
        var services = Enumerable.Range(0, count).Select(_ => new BleServiceUuid.Uuid128(new byte[16])).ToArray();
        var encoded = ContractJson.EncodeEvent(Advertisement(services));
        var observed = Assert.IsType<Event.BleAdvertisementObserved>(ContractJson.DecodeEvent(encoded)).Value;

        Assert.Equal("native-id", observed.Id);
        Assert.Equal(-42, observed.Rssi);
        Assert.Equal(count, observed.ServiceUuids.Count);
        Assert.All(observed.ServiceUuids, uuid => Assert.Equal(new byte[16], Assert.IsType<BleServiceUuid.Uuid128>(uuid).Value));
        Assert.Equal(encoded, ContractJson.EncodeEvent(new Event.BleAdvertisementObserved(observed)));
    }
}
