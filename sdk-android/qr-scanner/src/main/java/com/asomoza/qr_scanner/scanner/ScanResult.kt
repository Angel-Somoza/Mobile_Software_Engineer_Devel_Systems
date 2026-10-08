package com.asomoza.qr_scanner.scanner

sealed interface ScanResult {
    data class Success(
        val productId: Int
    ) : ScanResult

    data class Failure(
        val error: ScanErrors
    ) : ScanResult
}