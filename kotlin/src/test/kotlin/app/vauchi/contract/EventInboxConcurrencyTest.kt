// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

package app.vauchi.contract

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class EventInboxConcurrencyTest {
    @Test
    fun lifecycleChangesDuringValidationRejectTheCallbackWithoutBlockingOtherOperations() {
        for (change in listOf("cancel", "finish", "close")) {
            val inbox = EventInbox(InboxLimits(2, 4, 1024))
            val operation = (inbox.start() as OperationStart.Started).operation
            val entered = CountDownLatch(1)
            val resume = CountDownLatch(1)
            val workers = Executors.newFixedThreadPool(2)
            val data =
                object : AbstractList<UByte>() {
                    override val size = 1

                    override fun get(index: Int): UByte {
                        entered.countDown()
                        check(resume.await(5, TimeUnit.SECONDS)) { "callback was not released" }
                        return 7u
                    }
                }
            try {
                assertNull(operation.publish(Event.QrScanned("accepted")))
                val callback = workers.submit<DeliveryError?> { operation.publish(Event.DirectPayloadReceived(data)) }
                assertTrue("callback reached validation", entered.await(5, TimeUnit.SECONDS))
                val changed =
                    workers.submit<DeliveryError?> {
                        when (change) {
                            "finish" -> {
                                operation.finish()
                            }

                            "close" -> {
                                inbox.close()
                                null
                            }

                            else -> {
                                operation.cancel()
                                null
                            }
                        }
                    }
                assertNull(changed.get(5, TimeUnit.SECONDS))
                if (change != "close") {
                    val replacement = (inbox.start() as OperationStart.Started).operation
                    assertNull(replacement.publish(Event.WakeupFired))
                }
                resume.countDown()
                val expected = if (change == "close") DeliveryError.Closed else DeliveryError.Inactive
                assertEquals(expected, callback.get(5, TimeUnit.SECONDS))
                if (change == "finish") assertEquals(Event.QrScanned("accepted"), inbox.pop())
                if (change != "close") assertEquals(Event.WakeupFired, inbox.pop())
                assertNull(inbox.pop())
            } finally {
                resume.countDown()
                workers.shutdownNow()
                inbox.close()
            }
        }
    }

    @Test
    fun simultaneousPublishersRespectTheSharedQueueBudgetWithoutDroppingAcceptedEvents() {
        val inbox = EventInbox(InboxLimits(2, 1, 1024))
        val first = (inbox.start() as OperationStart.Started).operation
        val second = (inbox.start() as OperationStart.Started).operation
        val ready = CountDownLatch(2)
        val start = CountDownLatch(1)
        val workers = Executors.newFixedThreadPool(2)
        try {
            val results =
                listOf(first to Event.QrScanned("one"), second to Event.QrScanned("two")).map { (operation, event) ->
                    workers.submit<Pair<DeliveryError?, Event>> {
                        ready.countDown()
                        check(start.await(5, TimeUnit.SECONDS)) { "publishers were not started" }
                        operation.publish(event) to event
                    }
                }
            assertTrue("both publishers are ready", ready.await(5, TimeUnit.SECONDS))
            start.countDown()
            val observations = results.map { it.get(5, TimeUnit.SECONDS) }
            assertEquals(1, observations.count { it.first == null })
            assertEquals(1, observations.count { it.first == DeliveryError.Full })
            assertEquals(observations.single { it.first == null }.second, inbox.pop())
            assertNull(inbox.pop())
        } finally {
            start.countDown()
            workers.shutdownNow()
            inbox.close()
        }
    }
}
