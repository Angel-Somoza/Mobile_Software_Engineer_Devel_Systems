package com.asomoza.qr_scanner.scanner

import com.asomoza.qr_scanner.parser.QrParseResult
import com.asomoza.qr_scanner.parser.QrPayloadParser
import java.util.concurrent.atomic.AtomicBoolean

internal class ScanAttempt(private val onResult: (ScanResult) ->  Unit){

    private val finished = AtomicBoolean(false)

    val isFinished: Boolean get() = finished.get()

    fun qrDetected(raw: String?) {
        when (val parsed = QrPayloadParser.parse(raw)) {
            is QrParseResult.valid -> finish(ScanResult.Success(parsed.productId))
            is QrParseResult.invalid -> finish(ScanResult.Failure(ScanErrors.INVALID_QR))
        }
    }
    fun permissionDenied() = finish(ScanResult.Failure(ScanErrors.PERMISSION_DENIED))

    fun cameraUnavailable() = finish(ScanResult.Failure(ScanErrors.CAMERA_UNAVAILABLE))

    fun cancel() = finish(ScanResult.Failure(ScanErrors.CANCELLED))

    private fun finish(result: ScanResult){
        if(finished.compareAndSet(false, true)){
            onResult(result)
        }
    }
}