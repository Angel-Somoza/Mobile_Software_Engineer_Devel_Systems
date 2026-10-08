package com.asomoza.qr_scanner

import com.asomoza.qr_scanner.scanner.ScanErrors
import com.asomoza.qr_scanner.scanner.ScanManager
import com.asomoza.qr_scanner.scanner.ScanResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

class ScanManagerConcurrencyTest {

    @Test
    fun `dos inicios concurrentes solo permiten una sesion`() {
        repeat(200) { runOnce() }
    }

    private fun runOnce() {
        val manager = ScanManager()
        val ready = CountDownLatch(2)
        val startSignal = CountDownLatch(1)
        val done = CountDownLatch(2)

        val accepted = AtomicInteger(0)
        val rejected = AtomicInteger(0)
        val callbackResults = CopyOnWriteArrayList<ScanResult>()
        val threadErrors = CopyOnWriteArrayList<Throwable>()

        repeat(2) {
            thread {
                try {
                    ready.countDown()
                    startSignal.await()
                    val session = manager.start { callbackResults.add(it) }
                    if (session != null) accepted.incrementAndGet() else rejected.incrementAndGet()
                } catch (t: Throwable) {
                    threadErrors.add(t)
                } finally {
                    done.countDown()
                }
            }
        }

        assertTrue("Los hilos no quedaron listos", ready.await(5, TimeUnit.SECONDS))
        startSignal.countDown()
        assertTrue("Los hilos no terminaron", done.await(5, TimeUnit.SECONDS))

        assertTrue("Error en hilos: $threadErrors", threadErrors.isEmpty())
        assertEquals(1, accepted.get())
        assertEquals(1, rejected.get())
        assertEquals(
            listOf<ScanResult>(ScanResult.Failure(ScanErrors.PROGRESS_SCAN)),
            callbackResults.toList()
        )
    }
}