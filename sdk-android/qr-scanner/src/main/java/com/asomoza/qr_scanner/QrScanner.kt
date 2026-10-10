package com.asomoza.qr_scanner

import android.app.Activity
import android.content.Intent
import com.asomoza.qr_scanner.camera.QrScannerActivity
import com.asomoza.qr_scanner.scanner.ScanAttempt
import com.asomoza.qr_scanner.scanner.ScanManager
import com.asomoza.qr_scanner.scanner.ScanResult

object QrScanner {

    private val manager = ScanManager()

    @Volatile
    internal var currentAttempt: ScanAttempt? = null
        private set

    fun start(activity: Activity, onResult: (ScanResult) -> Unit) {
        val attempt = manager.start { result ->
            currentAttempt = null
            onResult(result)
        } ?: return

        currentAttempt = attempt
        activity.startActivity(Intent(activity, QrScannerActivity::class.java))
    }

    fun cancel() = manager.cancel()
}