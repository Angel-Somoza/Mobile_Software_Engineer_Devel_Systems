package com.asomoza.qr_scanner

import com.asomoza.qr_scanner.scanner.ScanErrors
import com.asomoza.qr_scanner.scanner.ScanManager
import com.asomoza.qr_scanner.scanner.ScanResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ScanManagerTest {
    private val results = mutableListOf<ScanResult>()

    private val sink: (ScanResult) -> Unit = {
        results.add(it)
    }

    @Test
    fun `segundo inicio con sesion activa`() {
        val manager = ScanManager()
        val firstResults = mutableListOf<ScanResult>()
        val secondResults = mutableListOf<ScanResult>()

        val first = manager.start { firstResults.add(it) }
        val second = manager.start { secondResults.add(it) }

        assertNotNull(first)
        assertNull(second)
        assertEquals(
            listOf<ScanResult>(ScanResult.Failure(ScanErrors.PROGRESS_SCAN)),
            secondResults
        )
        assertEquals(emptyList<ScanResult>(), firstResults)

        first!!.qrDetected("product:1")
        assertEquals(listOf<ScanResult>(ScanResult.Success(1)), firstResults)
        assertEquals(
            listOf<ScanResult>(ScanResult.Failure(ScanErrors.PROGRESS_SCAN)),
            secondResults
        )
    }

    @Test
    fun `tras terminar se puede iniciar otra sesion`() {
        val manager = ScanManager()
        manager.start(sink)!!.qrDetected("product:1")

        val next = manager.start(sink)
        assertNotNull(next)
        next!!.qrDetected("product:3")

        assertEquals(listOf<ScanResult>(ScanResult.Success(1), ScanResult.Success(3)), results)
    }

    @Test
    fun `cancela la sesion y libera el Manager`() {
        val manager = ScanManager()
        manager.start(sink)
        manager.cancel()
        manager.cancel()

        assertEquals(listOf<ScanResult>(ScanResult.Failure(ScanErrors.CANCELLED)), results)
        assertNotNull(manager.start(sink))
    }

    @Test
    fun `un rechazo no bloquea el manager despues`() {
        val manager = ScanManager()
        val first = manager.start(sink)
        assertNull(manager.start(sink))

        first!!.qrDetected("product:1")

        val third = manager.start(sink)
        assertNotNull(third)
        third!!.qrDetected("product:2")

        assertEquals(
            listOf(
                ScanResult.Failure(ScanErrors.PROGRESS_SCAN),
                ScanResult.Success(1),
                ScanResult.Success(2)
            ),
            results
        )
    }

    @Test
    fun `permiso denegado libera el manager`() {
        val manager = ScanManager()
        manager.start(sink)!!.permissionDenied()

        assertEquals(listOf<ScanResult>(ScanResult.Failure(ScanErrors.PERMISSION_DENIED)), results)
        assertNotNull(manager.start(sink))
    }

    @Test
    fun `camara no disponible libera el manager`() {
        val manager = ScanManager()
        manager.start(sink)!!.cameraUnavailable()

        assertEquals(listOf<ScanResult>(ScanResult.Failure(ScanErrors.CAMERA_UNAVAILABLE)), results)
        assertNotNull(manager.start(sink))
    }


}