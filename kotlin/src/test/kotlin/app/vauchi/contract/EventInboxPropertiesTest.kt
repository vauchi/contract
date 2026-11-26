// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import java.util.ArrayDeque

class EventInboxPropertiesTest {
    @Test
    fun randomLifetimesMatchTheReferenceQueue() =
        runBlocking<Unit> {
            checkAll(300, Arb.list(Arb.int(0..10_000), 50..200)) { steps ->
                val inbox = EventInbox(InboxLimits(3, 5, 1024))
                val handles = mutableListOf<Operation>()
                val active = mutableSetOf<Int>()
                val pending = ArrayDeque<Pair<Int, Event>>()
                for ((step, choice) in steps.withIndex()) {
                    val id = if (handles.isEmpty()) 0 else choice % handles.size
                    when (if (handles.isEmpty()) 0 else choice % 5) {
                        0 -> {
                            val result = inbox.start()
                            if (active.size == 3) {
                                assertEquals(OperationStart.Refused(DeliveryError.Full), result)
                            } else {
                                val operation = (result as OperationStart.Started).operation
                                active.add(handles.size)
                                handles.add(operation)
                            }
                        }

                        1 -> {
                            val event = Event.QrScanned("observation-$step")
                            val expected =
                                when {
                                    id !in active -> DeliveryError.Inactive
                                    pending.size == 5 -> DeliveryError.Full
                                    else -> null
                                }
                            assertEquals(expected, handles[id].publish(event))
                            if (expected == null) pending.addLast(id to event)
                        }

                        2 -> {
                            val expected = if (active.remove(id)) null else DeliveryError.Inactive
                            assertEquals(expected, handles[id].finish())
                        }

                        3 -> {
                            handles[id].cancel()
                            active.remove(id)
                            pending.removeIf { it.first == id }
                        }

                        else -> {
                            assertEquals(pending.pollFirst()?.second, inbox.pop())
                        }
                    }
                }
                while (pending.isNotEmpty()) assertEquals(pending.removeFirst().second, inbox.pop())
                assertNull(inbox.pop())
                inbox.close()
                assertEquals(OperationStart.Refused(DeliveryError.Closed), inbox.start())
                for (operation in handles) assertEquals(DeliveryError.Closed, operation.publish(Event.WakeupFired))
            }
        }

    @Test
    fun payloadBudgetMatchesEncodedUtf8ForArbitraryTextAndEscapes() =
        runBlocking<Unit> {
            val edges = Arb.element("", "\"\\\u0000\b\u000C\n\r\t", "é", "😀", "\u2028\u2029")
            checkAll(1000, Arb.string(0..512), edges) { text, edge ->
                val event = Event.QrScanned(edge + text + edge)
                val bytes = ContractJson.encodeEvent(event).toByteArray(Charsets.UTF_8).size
                val exact = EventInbox(InboxLimits(1, 1, bytes))
                val accepted = (exact.start() as OperationStart.Started).operation
                assertNull(accepted.publish(event))
                assertSame(event, exact.pop())
                val smaller = EventInbox(InboxLimits(1, 1, bytes - 1))
                val refused = (smaller.start() as OperationStart.Started).operation
                assertEquals(DeliveryError.PayloadTooLarge, refused.publish(event))
                assertNull(smaller.pop())
                exact.close()
                smaller.close()
            }
        }
}
