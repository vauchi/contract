// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace Vauchi.Contract.Tests;

/// <summary>
/// The lifetime rules of <c>tests/shared/executor_conformance.rs</c>, case
/// for case. Events are compared by what they write: a record holding a
/// byte array is equal only to itself.
/// </summary>
public class EventInboxTests
{
    private static EventInbox Inbox(int operations, int events, int bytes) =>
        new(new InboxLimits(operations, events, bytes));

    private static Event Found(string id) =>
        new Event.BleDeviceDiscovered { Id = id, Rssi = -42, AdvData = new byte[] { 1, 2, 3 } };

    private static string? Wire(Event? observation) =>
        observation is null ? null : Encoding.UTF8.GetString(ContractJson.EncodeEvent(observation));

    private static Operation Started(EventInbox inbox)
    {
        Assert.True(inbox.TryStart(out Operation? operation, out DeliveryError? refusal));
        Assert.Null(refusal);
        return operation!;
    }

    private static DeliveryError? StartRefusal(EventInbox inbox)
    {
        Assert.False(inbox.TryStart(out Operation? operation, out DeliveryError? refusal));
        Assert.Null(operation);
        return refusal;
    }

    private static void AssertNext(EventInbox inbox, Event? expected) =>
        Assert.Equal(Wire(expected), Wire(inbox.Pop()));

    [Fact]
    public void CallbackObservationsAreDeliveredInAcceptanceOrder()
    {
        using EventInbox inbox = Inbox(2, 3, 1024);
        Operation first = Started(inbox);
        Operation second = Started(inbox);

        Assert.Null(first.Publish(Found("one")));
        Assert.Null(second.Publish(Found("two")));
        Assert.Null(first.Publish(Found("three")));

        AssertNext(inbox, Found("one"));
        AssertNext(inbox, Found("two"));
        AssertNext(inbox, Found("three"));
        AssertNext(inbox, null);
    }

    [Fact]
    public void CancelDiscardsBufferedEventsAndRejectsLateCallbacks()
    {
        using EventInbox inbox = Inbox(2, 4, 1024);
        Operation cancelled = Started(inbox);
        Operation survivor = Started(inbox);
        Assert.Null(cancelled.Publish(Found("stale")));
        Assert.Null(survivor.Publish(Found("current")));

        cancelled.Cancel();
        Operation replacement = Started(inbox);

        Assert.Equal(DeliveryError.Inactive, cancelled.Publish(Found("late")));
        Assert.Null(replacement.Publish(Found("replacement")));
        AssertNext(inbox, Found("current"));
        AssertNext(inbox, Found("replacement"));
        AssertNext(inbox, null);
    }

    [Fact]
    public void CancelBeforeTheFirstCallbackIsIdempotent()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);

        operation.Cancel();
        operation.Cancel();

        Assert.Equal(DeliveryError.Inactive, operation.Publish(Found("late")));
        AssertNext(inbox, null);
        Operation replacement = Started(inbox);
        Assert.Null(replacement.Publish(Found("new")));
        AssertNext(inbox, Found("new"));
    }

    [Fact]
    public void AFullInboxReportsBackpressureWithoutReplacingAcceptedEvents()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);

        Assert.Equal(DeliveryError.Full, StartRefusal(inbox));
        Assert.Null(operation.Publish(Found("first")));
        Assert.Equal(DeliveryError.Full, operation.Publish(Found("second")));

        AssertNext(inbox, Found("first"));
        Assert.Null(operation.Publish(Found("second")));
        AssertNext(inbox, Found("second"));
    }

    [Fact]
    public void ThePayloadLimitIsInclusiveAndARejectionConsumesNoCapacity()
    {
        Event observation = Found("bounded");
        int size = ContractJson.EncodeEvent(observation).Length;
        using EventInbox exact = Inbox(1, 1, size);
        Assert.Null(Started(exact).Publish(observation));
        AssertNext(exact, observation);

        using EventInbox smaller = Inbox(1, 1, size - 1);
        Operation operation = Started(smaller);
        Assert.Equal(DeliveryError.PayloadTooLarge, operation.Publish(observation));

        Event shorter = new Event.HardwareUnavailable { Transport = "BLE" };
        Assert.Null(operation.Publish(shorter));
        AssertNext(smaller, shorter);
    }

    [Fact]
    public void AnEventThatCannotBeWrittenIsRefusedAsInvalid()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);
        Event unwritable = new Event.LocationResult { Latitude = double.NaN, Longitude = 0, AccuracyMeters = null };

        Assert.Equal(DeliveryError.InvalidEvent, operation.Publish(unwritable));
        AssertNext(inbox, null);
        Assert.Null(operation.Publish(Found("next")));
    }

    [Fact]
    public void ClosingDiscardsPendingEventsAndClosesExistingAndNewProducers()
    {
        using EventInbox inbox = Inbox(1, 2, 1024);
        Operation operation = Started(inbox);
        Assert.Null(operation.Publish(Found("pending")));

        inbox.Close();
        inbox.Close();

        AssertNext(inbox, null);
        Assert.Equal(DeliveryError.Closed, operation.Publish(Found("late")));
        Assert.Equal(DeliveryError.Closed, operation.Finish());
        Assert.Equal(DeliveryError.Closed, StartRefusal(inbox));
    }

    [Fact]
    public void DisposingTheInboxClosesCallbacksThatOutliveIt()
    {
        Operation operation;
        using (EventInbox inbox = Inbox(1, 1, 1024))
        {
            operation = Started(inbox);
        }

        Assert.Equal(DeliveryError.Closed, operation.Publish(Found("late")));
    }

    [Fact]
    public void PermissionFailureAndDisconnectObservationsAreNotReinterpreted()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);
        Event[] observations =
        {
            new Event.PermissionDenied { Transport = "BLE" },
            new Event.HardwareUnavailable { Transport = "BLE" },
            new Event.HardwareError { Transport = "BLE", Error = "OS failure" },
            new Event.BleDisconnected { DeviceId = "peer", Direction = BleLinkDirection.Outbound, Reason = "link closed" },
        };

        foreach (Event observation in observations)
        {
            Assert.Null(operation.Publish(observation));
            Assert.Same(observation, inbox.Pop());
        }
    }

    [Fact]
    public async Task ACancelledCallbackOnAnotherThreadCannotReachAReplacementOperation()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);
        using var release = new SemaphoreSlim(0);
        Task<DeliveryError?> worker = Task.Run(async () =>
        {
            await release.WaitAsync();
            return operation.Publish(Found("late"));
        });

        operation.Cancel();
        Operation replacement = Started(inbox);
        release.Release();

        Assert.Equal(DeliveryError.Inactive, await worker);
        Assert.Null(replacement.Publish(Found("replacement")));
        AssertNext(inbox, Found("replacement"));
        AssertNext(inbox, null);
    }

    [Fact]
    public void FinishPreservesTheFinalObservationAndReleasesOperationCapacity()
    {
        using EventInbox inbox = Inbox(1, 2, 1024);
        Operation operation = Started(inbox);
        Assert.Null(operation.Publish(Found("final")));

        Assert.Null(operation.Finish());
        Operation next = Started(inbox);

        Assert.Null(next.Publish(Found("next")));
        Assert.Equal(DeliveryError.Inactive, operation.Publish(Found("late")));
        Assert.Equal(DeliveryError.Inactive, operation.Finish());
        AssertNext(inbox, Found("final"));
        AssertNext(inbox, Found("next"));
        AssertNext(inbox, null);
    }

    [Fact]
    public void ARejectedEventCanBePublishedAgainOnceThereIsRoom()
    {
        using EventInbox inbox = Inbox(1, 1, 1024);
        Operation operation = Started(inbox);
        Event retried = Found("retry");
        Assert.Null(operation.Publish(Found("first")));

        Assert.Equal(DeliveryError.Full, operation.Publish(retried));
        AssertNext(inbox, Found("first"));

        Assert.Null(operation.Publish(retried));
        Assert.Same(retried, inbox.Pop());
    }

    [Fact]
    public async Task ConcurrentProducersNeverExceedTheEventBudgetOrLoseAnAcceptedEvent()
    {
        const int Producers = 8;
        const int PerProducer = 200;
        using EventInbox inbox = Inbox(Producers, 16, 1024);
        int accepted = 0;
        var producers = new Task[Producers];
        for (int index = 0; index < Producers; index++)
        {
            Operation operation = Started(inbox);
            producers[index] = Task.Run(() =>
            {
                for (int sent = 0; sent < PerProducer; sent++)
                {
                    if (operation.Publish(Found("x")) is null)
                    {
                        Interlocked.Increment(ref accepted);
                    }
                }
            });
        }

        int taken = 0;
        Task finished = Task.WhenAll(producers);
        while (!finished.IsCompleted)
        {
            if (inbox.Pop() is not null)
            {
                taken++;
            }
        }
        await finished;
        int left = 0;
        while (inbox.Pop() is not null)
        {
            left++;
        }

        Assert.InRange(left, 0, 16);
        Assert.Equal(Volatile.Read(ref accepted), taken + left);
    }

    [Theory]
    [InlineData(0, 1, 1)]
    [InlineData(1, 0, 1)]
    [InlineData(1, 1, 0)]
    [InlineData(-1, 1, 1)]
    public void ABudgetOfZeroIsRefusedWhenTheLimitsAreMade(int operations, int events, int bytes)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new InboxLimits(operations, events, bytes));
    }
}
