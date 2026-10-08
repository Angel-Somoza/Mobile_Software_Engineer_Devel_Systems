package com.example.qr_scanner

import com.example.qr_scanner.scanner.ScanAttempt
import com.example.qr_scanner.scanner.ScanErrors
import com.example.qr_scanner.scanner.ScanResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScanAttemptTest {

    private val results = mutableListOf<ScanResult>()
    private val sink: (ScanResult) -> Unit = { results.add(it) }

    @Test fun `detecciones repetidas entregan un solo resultado`() {
        val session = ScanAttempt(sink)
        repeat(10) { session.qrDetected("product:1") }
        assertEquals(listOf<ScanResult>(ScanResult.Success(1)), results)
    }

    @Test fun `qr invalido termina una sola vez`() {
        val session = ScanAttempt(sink)
        session.qrDetected("hola")
        session.qrDetected("product:1")
        assertEquals(listOf<ScanResult>(ScanResult.Failure(ScanErrors.INVALID_QR)), results)
    }

    @Test fun `cancelar y luego detectar ignora la deteccion tardia`() {
        val session = ScanAttempt(sink)
        session.cancel()
        session.qrDetected("product:1")
        assertEquals(listOf<ScanResult>(ScanResult.Failure(ScanErrors.CANCELLED)), results)
    }

    @Test fun `detectar y luego cancelar ignora la cancelacion`() {
        val session = ScanAttempt(sink)
        session.qrDetected("product:2")
        session.cancel()
        assertEquals(listOf<ScanResult>(ScanResult.Success(2)), results)
    }

    @Test fun `permiso denegado`() {
        val session = ScanAttempt(sink)

        session.permissionDenied()
        session.qrDetected("product:1")
        session.cancel()

        assertEquals(
            listOf<ScanResult>(
                ScanResult.Failure(ScanErrors.PERMISSION_DENIED)
            ),
            results
        )
        assertTrue(session.isFinished)
    }

    @Test fun `camara no disponible`() {
        val session = ScanAttempt(sink)
        session.cameraUnavailable()
        session.qrDetected("product:1")
        session.cancel()

        assertEquals(
            listOf<ScanResult>(ScanResult.Failure(ScanErrors.CAMERA_UNAVAILABLE)),
            results
        )
        assertTrue(session.isFinished)
    }

    @Test fun `sesion nueva no esta terminada`() {
        val session = ScanAttempt(sink)
        assertFalse(session.isFinished)
        assertEquals(emptyList<ScanResult>(), results)
    }

    @Test fun `entre dos terminales gana el primero`() {
        val session = ScanAttempt(sink)
        session.cameraUnavailable()
        session.permissionDenied()

        assertEquals(
            listOf<ScanResult>(ScanResult.Failure(ScanErrors.CAMERA_UNAVAILABLE)),
            results
        )
    }


}