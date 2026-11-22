// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Text.Json;

namespace Vauchi.Contract
{
    /// <summary>
    /// Host resource budgets. An event's size is the bytes this library
    /// writes for it. OS capture buffers must be bounded by their executor
    /// before an event is built from them.
    /// </summary>
    public readonly record struct InboxLimits
    {
        public InboxLimits(int operations, int events, int eventBytes)
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(operations);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(events);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(eventBytes);
            Operations = operations;
            Events = events;
            EventBytes = eventBytes;
        }

        public int Operations { get; }

        public int Events { get; }

        public int EventBytes { get; }
    }

    public enum DeliveryError
    {
        /// <summary>The inbox or its operation budget is full: backpressure, not a failure.</summary>
        Full,

        /// <summary>The operation was finished or cancelled.</summary>
        Inactive,

        /// <summary>The inbox was closed.</summary>
        Closed,

        /// <summary>The event is larger than the byte budget.</summary>
        PayloadTooLarge,

        /// <summary>The event cannot be written as contract JSON.</summary>
        InvalidEvent,
    }

    /// <summary>
    /// Bounded delivery of observations from asynchronous OS callbacks to
    /// the one host that hands them to Core: <c>src/executor.rs</c> in C#.
    ///
    /// An <see cref="Operation"/> is a local callback lifetime, never an
    /// identifier on the wire. Cancelling one stops delivery; it does not
    /// interrupt an OS call, which its owner stops. Closing or disposing
    /// the inbox discards what is queued and refuses every producer, also
    /// those native callbacks still hold.
    /// </summary>
    public sealed class EventInbox : IDisposable
    {
        private readonly InboxState _state;

        public EventInbox(InboxLimits limits)
        {
            // A default-constructed limits value skips the constructor's checks.
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limits.Operations);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limits.Events);
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limits.EventBytes);
            _state = new InboxState(limits);
        }

        /// <summary>Reserve a callback lifetime before starting native work.</summary>
        public bool TryStart(out Operation? operation, out DeliveryError? refusal)
        {
            lock (_state)
            {
                refusal = _state.Closed ? DeliveryError.Closed
                    : _state.Active.Count == _state.Limits.Operations ? DeliveryError.Full
                    : null;
                if (refusal is not null)
                {
                    operation = null;
                    return false;
                }
                ulong id = _state.NextId++;
                _state.Active.Add(id);
                operation = new Operation(_state, id);
                return true;
            }
        }

        /// <summary>
        /// The oldest accepted observation, or null. The host serializes
        /// dispatch and cancellation: an event already taken is the host's.
        /// </summary>
        public Event? Pop()
        {
            lock (_state)
            {
                return _state.Pending.Count == 0 ? null : _state.Pending.Dequeue().Observation;
            }
        }

        /// <summary>Discard pending observations and refuse all producers from now on.</summary>
        public void Close()
        {
            lock (_state)
            {
                _state.Closed = true;
                _state.Active.Clear();
                _state.Pending.Clear();
            }
        }

        public void Dispose() => Close();
    }

    /// <summary>
    /// A callback handle. Finish a completed operation, cancel an aborted
    /// one; the host does one of the two for every lifetime to release its
    /// place in the operation budget.
    /// </summary>
    public sealed class Operation
    {
        private readonly InboxState _state;
        private readonly ulong _id;

        internal Operation(InboxState state, ulong id)
        {
            _state = state;
            _id = id;
        }

        /// <summary>
        /// Queue an observation unchanged; null when it was accepted.
        /// <see cref="DeliveryError.Full"/> is backpressure: keep the one
        /// event and publish it again, or end the native work. No retry or
        /// fallback decision belongs here.
        /// </summary>
        public DeliveryError? Publish(Event observation)
        {
            ArgumentNullException.ThrowIfNull(observation);
            int limit;
            lock (_state)
            {
                if (Refusal() is { } early)
                {
                    return early;
                }
                limit = _state.Limits.EventBytes;
            }
            // Measured outside the lock: a large event must not hold up the host.
            if (BoundedSize.Check(observation, limit) is { } unfit)
            {
                return unfit;
            }
            lock (_state)
            {
                if (Refusal() is { } late)
                {
                    return late;
                }
                if (_state.Pending.Count == _state.Limits.Events)
                {
                    return DeliveryError.Full;
                }
                _state.Pending.Enqueue((_id, observation));
                return null;
            }
        }

        /// <summary>
        /// Seal a completed operation and keep what it already queued. Late
        /// callbacks are refused and another operation can take its place.
        /// </summary>
        public DeliveryError? Finish()
        {
            lock (_state)
            {
                if (Refusal() is { } refusal)
                {
                    return refusal;
                }
                _state.Active.Remove(_id);
                return null;
            }
        }

        /// <summary>
        /// End this lifetime and drop what it queued, leaving other
        /// operations untouched. Cancelling twice is harmless.
        /// </summary>
        public void Cancel()
        {
            lock (_state)
            {
                _state.Active.Remove(_id);
                if (_state.Pending.Count == 0)
                {
                    return;
                }
                var kept = new Queue<(ulong Operation, Event Observation)>(_state.Pending.Count);
                foreach (var queued in _state.Pending)
                {
                    if (queued.Operation != _id)
                    {
                        kept.Enqueue(queued);
                    }
                }
                _state.Pending = kept;
            }
        }

        private DeliveryError? Refusal() =>
            _state.Closed ? DeliveryError.Closed
            : !_state.Active.Contains(_id) ? DeliveryError.Inactive
            : null;
    }

    internal sealed class InboxState
    {
        internal InboxState(InboxLimits limits) => Limits = limits;

        internal InboxLimits Limits { get; }

        internal ulong NextId { get; set; }

        internal HashSet<ulong> Active { get; } = new();

        internal Queue<(ulong Operation, Event Observation)> Pending { get; set; } = new();

        internal bool Closed { get; set; }
    }

    /// <summary>
    /// Measures an event against the byte budget while writing it into one
    /// reused block, so an event over the budget is never copied whole.
    /// </summary>
    internal static class BoundedSize
    {
        internal static DeliveryError? Check(Event observation, int limit)
        {
            var counter = new Counter(limit);
            try
            {
                using (var writer = new Utf8JsonWriter(counter))
                {
                    observation.Write(writer);
                }
                return null;
            }
            catch (BudgetExceeded)
            {
                return DeliveryError.PayloadTooLarge;
            }
            catch (Exception error) when (error is ContractJsonException or InvalidOperationException or ArgumentException)
            {
                return DeliveryError.InvalidEvent;
            }
            finally
            {
                counter.Release();
            }
        }

        private sealed class BudgetExceeded : Exception
        {
        }

        private sealed class Counter : IBufferWriter<byte>
        {
            private readonly int _limit;
            private byte[] _block = ArrayPool<byte>.Shared.Rent(256);
            private long _written;

            internal Counter(int limit) => _limit = limit;

            public void Advance(int count)
            {
                _written += count;
                if (_written > _limit)
                {
                    throw new BudgetExceeded();
                }
            }

            public Memory<byte> GetMemory(int sizeHint = 0) => Block(sizeHint);

            public Span<byte> GetSpan(int sizeHint = 0) => Block(sizeHint);

            internal void Release() => ArrayPool<byte>.Shared.Return(_block);

            private byte[] Block(int sizeHint)
            {
                if (sizeHint > _block.Length)
                {
                    ArrayPool<byte>.Shared.Return(_block);
                    _block = ArrayPool<byte>.Shared.Rent(sizeHint);
                }
                return _block;
            }
        }
    }
}
