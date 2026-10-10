package com.asomoza.qr_scanner

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.asomoza.qr_scanner.camera.QrScannerActivity
import com.asomoza.qr_scanner.scanner.ScanAttempt
import com.asomoza.qr_scanner.scanner.ScanManager
import com.asomoza.qr_scanner.scanner.ScanResult

object QrScanner {

    private val manager = ScanManager()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    internal var currentAttempt: ScanAttempt? = null
        private set

    @Volatile
    internal var closeScreen: (() -> Unit)? = null

    fun start(context: Context, onResult: (ScanResult) -> Unit) {
        val attempt = manager.start { result ->
            currentAttempt = null
            mainHandler.post { closeScreen?.invoke() }
            onResult(result)
        } ?: return

        currentAttempt = attempt
        val intent = Intent(context, QrScannerActivity::class.java)
        if (context !is Activity) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun cancel() = manager.cancel()
}