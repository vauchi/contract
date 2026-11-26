// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test

class EventInboxTest {
    private fun started(inbox: EventInbox): Operation = (inbox.start() as OperationStart.Started).operation

    private fun found(id: String): Event = Event.BleDeviceDiscovered(id = id, rssi = -42, advData = listOf(1u, 2u, 3u))

    @Test
    fun observationsAreDeliveredInAcceptanceOrder() {
        val inbox = EventInbox(InboxLimits(2, 3, 1024))
        val first = started(inbox)
        val second = started(inbox)
        assertNull(first.publish(found("one")))
        assertNull(second.publish(found("two")))
        assertNull(first.publish(found("three")))
        assertEquals(found("one"), inbox.pop())
        assertEquals(found("two"), inbox.pop())
        assertEquals(found("three"), inbox.pop())
        assertNull(inbox.pop())
    }

    @Test
    fun cancellationPurgesOnlyItsOwnEventsAndLateCallbacksCannotReachAReplacement() {
        val inbox = EventInbox(InboxLimits(2, 3, 1024))
        val cancelled = started(inbox)
        val survivor = started(inbox)
        assertNull(cancelled.publish(found("stale")))
        assertNull(survivor.publish(found("current")))
        cancelled.cancel()
        cancelled.cancel()
        val replacement = started(inbox)
        assertEquals(DeliveryError.Inactive, cancelled.publish(found("late")))
        assertNull(replacement.publish(found("replacement")))
        assertEquals(found("current"), inbox.pop())
        assertEquals(found("replacement"), inbox.pop())
        assertNull(inbox.pop())
    }

    @Test
    fun fullIsBackpressureAndTheProducerCanRetryItsUnchangedEvent() {
        val inbox = EventInbox(InboxLimits(1, 1, 1024))
        val operation = started(inbox)
        assertEquals(OperationStart.Refused(DeliveryError.Full), inbox.start())
        assertNull(operation.publish(found("first")))
        val retry = found("retry")
        assertEquals(DeliveryError.Full, operation.publish(retry))
        assertEquals(found("first"), inbox.pop())
        assertNull(operation.publish(retry))
        assertSame(retry, inbox.pop())
    }

    @Test
    fun finishKeepsAcceptedEventsAndReleasesTheOperationBudget() {
        val inbox = EventInbox(InboxLimits(1, 2, 1024))
        val finished = started(inbox)
        assertNull(finished.publish(found("final")))
        assertNull(finished.finish())
        assertEquals(DeliveryError.Inactive, finished.finish())
        assertEquals(DeliveryError.Inactive, finished.publish(found("late")))
        val next = started(inbox)
        assertNull(next.publish(found("next")))
        assertEquals(found("final"), inbox.pop())
        assertEquals(found("next"), inbox.pop())
        assertNull(inbox.pop())
    }

    @Test
    fun closingDiscardsPendingDataAndPermanentlyRejectsExistingAndNewProducers() {
        val inbox = EventInbox(InboxLimits(1, 2, 1024))
        val operation = started(inbox)
        assertNull(operation.publish(found("pending")))
        inbox.close()
        inbox.close()
        assertNull(inbox.pop())
        assertEquals(DeliveryError.Closed, operation.publish(found("late")))
        assertEquals(DeliveryError.Closed, operation.finish())
        assertEquals(OperationStart.Refused(DeliveryError.Closed), inbox.start())
        operation.cancel()
        assertNull(inbox.pop())
    }

    @Test
    fun cancellingAFinishedOperationStillRemovesItsBufferedEvents() {
        val inbox = EventInbox(InboxLimits(1, 2, 1024))
        val operation = started(inbox)
        assertNull(operation.publish(found("buffered")))
        assertNull(operation.finish())
        operation.cancel()
        assertNull(inbox.pop())
    }

    @Test
    fun nativeOutcomesAreDeliveredWithoutInterpretation() {
        val inbox = EventInbox(InboxLimits(1, 1, 1024))
        val operation = started(inbox)
        for (event in listOf(
            Event.PermissionDenied("ble"),
            Event.HardwareUnavailable("ble"),
            Event.HardwareError("native_failure", "ble"),
        )) {
            assertNull(operation.publish(event))
            assertSame(event, inbox.pop())
        }
    }

    @Test
    fun resourceBudgetsMustBePositive() {
        for (values in listOf(listOf(0, 1, 1), listOf(1, 0, 1), listOf(1, 1, 0), listOf(-1, 1, 1))) {
            val error = assertThrows(IllegalArgumentException::class.java) { InboxLimits(values[0], values[1], values[2]) }
            assertEquals("inbox budgets must be positive", error.message)
        }
    }
}
