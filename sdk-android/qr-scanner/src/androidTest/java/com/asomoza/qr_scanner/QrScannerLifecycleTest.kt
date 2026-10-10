package com.asomoza.qr_scanner

import android.Manifest
import androidx.activity.ComponentActivity
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import com.asomoza.qr_scanner.camera.QrScannerActivity
import com.asomoza.qr_scanner.scanner.ScanErrors
import com.asomoza.qr_scanner.scanner.ScanResult
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.Timeout   // NUEVO
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class QrScannerLifecycleTest {

    @get:Rule
    val cameraPermission: GrantPermissionRule =
        GrantPermissionRule.grant(Manifest.permission.CAMERA)

    @get:Rule
    val testTimeout: Timeout = Timeout.seconds(30)   // NUEVO

    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @After
    fun tearDown() {
        instrumentation.runOnMainSync { QrScanner.cancel() }
    }

    @Test
    fun cancel_deliversCancelled_closesScreen_andReleasesSession() {
        val results = mutableListOf<ScanResult>()
        val resultLatch = CountDownLatch(1)
        val monitor = instrumentation.addMonitor(QrScannerActivity::class.java.name, null, false)

        ActivityScenario.launch(ComponentActivity::class.java).use { hostScenario ->
            hostScenario.onActivity { host ->
                QrScanner.start(host) {
                    results.add(it)
                    resultLatch.countDown()
                }
            }

            val scanner = instrumentation.waitForMonitorWithTimeout(monitor, TIMEOUT_MS)
            assertNotNull("La pantalla de escaneo no se abrio", scanner)
            waitUntil("La pantalla no se registro") { QrScanner.closeScreen != null }

            instrumentation.runOnMainSync { QrScanner.cancel() }

            assertTrue("No llego resultado", resultLatch.await(TIMEOUT_MS, TimeUnit.MILLISECONDS))
            assertEquals(listOf(ScanResult.Failure(ScanErrors.CANCELLED)), results)

            waitUntil("La Activity no se destruyo") { scanner.isDestroyed }
            assertNull("La sesion no se libero", QrScanner.currentAttempt)
            assertNull("La pantalla no se dio de baja", QrScanner.closeScreen)
        }
    }

    @Test
    fun afterCancel_aNewSessionCanStart() {
        val firstLatch = CountDownLatch(1)
        instrumentation.runOnMainSync {
            QrScanner.start(ApplicationProvider.getApplicationContext()) { firstLatch.countDown() }
            QrScanner.cancel()
        }
        assertTrue("La primera sesion no termino", firstLatch.await(TIMEOUT_MS, TimeUnit.MILLISECONDS))

        var secondResult: ScanResult? = null
        val secondLatch = CountDownLatch(1)
        instrumentation.runOnMainSync {
            QrScanner.start(ApplicationProvider.getApplicationContext()) {
                secondResult = it
                secondLatch.countDown()
            }
        }
        assertNotNull("La segunda sesion no arranco", QrScanner.currentAttempt)

        instrumentation.runOnMainSync { QrScanner.cancel() }
        assertTrue("La segunda sesion no termino", secondLatch.await(TIMEOUT_MS, TimeUnit.MILLISECONDS))
        assertEquals(ScanResult.Failure(ScanErrors.CANCELLED), secondResult)
    }

    private fun waitUntil(failureMessage: String, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + TIMEOUT_MS
        while (!condition() && System.currentTimeMillis() < deadline) {
            Thread.sleep(POLL_INTERVAL_MS)
        }
        assertTrue(failureMessage, condition())
    }

    private companion object {
        const val TIMEOUT_MS = 5_000L
        const val POLL_INTERVAL_MS = 50L
    }
}