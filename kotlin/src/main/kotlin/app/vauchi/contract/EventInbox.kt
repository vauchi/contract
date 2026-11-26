// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import java.lang.ref.WeakReference
import java.util.ArrayDeque

/** Host budgets; native capture buffers must be bounded before constructing events. */
data class InboxLimits(
    val operations: Int,
    val events: Int,
    val eventBytes: Int,
) {
    init {
        require(operations > 0 && events > 0 && eventBytes > 0) { "inbox budgets must be positive" }
    }
}

enum class DeliveryError {
    Full,
    Inactive,
    Closed,
    PayloadTooLarge,
    InvalidEvent,
}

sealed interface OperationStart {
    data class Started(
        val operation: Operation,
    ) : OperationStart

    data class Refused(
        val reason: DeliveryError,
    ) : OperationStart
}

internal class InboxState(
    val limits: InboxLimits,
) {
    class Pending(
        val id: Long,
        val event: Event,
    )

    var nextId = 0L
    var closed = false
    val active = mutableSetOf<Long>()
    val pending = ArrayDeque<Pending>()

    fun check(id: Long): DeliveryError? =
        when {
            closed -> DeliveryError.Closed
            id !in active -> DeliveryError.Inactive
            else -> null
        }
}

/** One host-owned queue; closing it discards all accepted observations. */
class EventInbox(
    limits: InboxLimits,
) : AutoCloseable {
    private val state = InboxState(limits)

    fun start(): OperationStart =
        synchronized(state) {
            when {
                state.closed -> {
                    OperationStart.Refused(DeliveryError.Closed)
                }

                state.active.size == state.limits.operations || state.nextId == Long.MAX_VALUE -> {
                    OperationStart.Refused(DeliveryError.Full)
                }

                else -> {
                    val id = state.nextId++
                    state.active.add(id)
                    OperationStart.Started(Operation(state, id))
                }
            }
        }

    /** The host serializes dispatch and cancellation after taking ownership here. */
    fun pop(): Event? = synchronized(state) { state.pending.pollFirst()?.event }

    override fun close() {
        synchronized(state) {
            state.closed = true
            state.active.clear()
            state.pending.clear()
        }
    }
}

/** A local callback lifetime, never a serialized domain id. Finish or cancel explicitly. */
class Operation internal constructor(
    state: InboxState,
    private val id: Long,
) {
    private val shared = WeakReference(state)

    /**
     * Null accepts the unchanged event; the producer must not mutate it afterwards.
     * On Full the producer still owns it for bounded retry or termination of native work.
     */
    fun publish(event: Event): DeliveryError? {
        val state = shared.get() ?: return DeliveryError.Closed
        val limit =
            synchronized(state) {
                state.check(id)?.let { return it }
                state.limits.eventBytes
            }
        validateEventBudget(event, limit)?.let { return it }
        return synchronized(state) {
            state.check(id) ?: if (state.pending.size == state.limits.events) {
                DeliveryError.Full
            } else {
                state.pending.addLast(InboxState.Pending(id, event))
                null
            }
        }
    }

    /** Seal callbacks and release the operation slot while keeping accepted events. */
    fun finish(): DeliveryError? {
        val state = shared.get() ?: return DeliveryError.Closed
        return synchronized(state) {
            state.check(id)?.let { return it }
            state.active.remove(id)
            null
        }
    }

    /** Purge this lifetime's pending events; the host also stops its native resources. */
    fun cancel() {
        val state = shared.get() ?: return
        synchronized(state) {
            state.active.remove(id)
            state.pending.removeIf { it.id == id }
        }
    }
}
