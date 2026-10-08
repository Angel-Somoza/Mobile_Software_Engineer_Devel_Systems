package com.asomoza.qr_scanner.scanner

internal class ScanManager {

    private val lock = Any()
    private var active: ScanAttempt? = null

    fun start(onResult: (ScanResult) -> Unit): ScanAttempt? {
        val session: ScanAttempt? = synchronized(lock) {
            if (active != null) {
                null
            } else {
                ScanAttempt { result ->
                    synchronized(lock) { active = null }
                    onResult(result)
                }.also { active = it }
            }
        }
        if (session == null) {
            onResult(ScanResult.Failure(ScanErrors.PROGRESS_SCAN))
        }
        return session
    }

    fun cancel() {
        val current = synchronized(lock) {
            active
        }
        current?.cancel()
    }
}





