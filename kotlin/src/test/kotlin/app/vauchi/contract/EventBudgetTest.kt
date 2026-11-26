// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class EventBudgetTest {
    private fun started(inbox: EventInbox): Operation = (inbox.start() as OperationStart.Started).operation

    @Test
    fun byteBudgetIsInclusiveForEscapesAndMultibyteUnicode() {
        val event = Event.QrScanned("é😀\n\"\\\u0001")
        val bytes = ContractJson.encodeEvent(event).toByteArray(Charsets.UTF_8).size
        val exact = EventInbox(InboxLimits(1, 1, bytes))
        assertNull(started(exact).publish(event))
        assertSame(event, exact.pop())
        val smaller = EventInbox(InboxLimits(1, 1, bytes - 1))
        val operation = started(smaller)
        assertEquals(DeliveryError.PayloadTooLarge, operation.publish(event))
        assertNull(smaller.pop())
        assertNull(operation.publish(Event.WakeupFired))
        assertEquals(Event.WakeupFired, smaller.pop())
    }

    @Test
    fun invalidEventsDoNotConsumeCapacityOrExposePayloadData() {
        val inbox = EventInbox(InboxLimits(1, 1, 1024))
        val operation = started(inbox)
        assertEquals(DeliveryError.InvalidEvent, operation.publish(Event.AudioSamplesRecorded(1u, listOf(Float.NaN))))
        assertEquals(DeliveryError.InvalidEvent, operation.publish(Event.QrScanned("private\uD800")))
        assertNull(inbox.pop())
        assertNull(operation.publish(Event.WakeupFired))
        assertEquals(Event.WakeupFired, inbox.pop())
    }

    @Test
    fun oversizedPayloadIsStoppedWithoutBuildingAFullSerializedCopy() {
        var reads = 0
        val data =
            object : AbstractList<UByte>() {
                override val size: Int = 10_000_000

                override fun get(index: Int): UByte {
                    reads++
                    check(reads <= 128) { "budget traversal did not stop" }
                    return 255u
                }
            }
        val inbox = EventInbox(InboxLimits(1, 1, 64))
        assertEquals(DeliveryError.PayloadTooLarge, started(inbox).publish(Event.DirectPayloadReceived(data)))
        assertTrue("bounded traversal", reads in 1..128)
        assertNull(inbox.pop())
    }

    @Test
    fun inactiveAndClosedLifetimesAreRejectedBeforeLookingAtPayloads() {
        val event = Event.QrScanned("\uD800")
        val inbox = EventInbox(InboxLimits(1, 1, 8))
        val operation = started(inbox)
        operation.cancel()
        assertEquals(DeliveryError.Inactive, operation.publish(event))
        inbox.close()
        assertEquals(DeliveryError.Closed, operation.publish(event))
    }
}
