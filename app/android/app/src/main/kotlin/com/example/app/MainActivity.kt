package com.example.app

import com.asomoza.qr_scanner.QrScanner
import com.asomoza.qr_scanner.scanner.ScanResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.asomoza.flash_orders/qr_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> startScan(result)
                    "cancelScan" -> {
                        QrScanner.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startScan(result: MethodChannel.Result) {
        QrScanner.start(this) { scanResult ->
            runOnUiThread {
                when (scanResult) {
                    is ScanResult.Success -> result.success(scanResult.productId)
                    is ScanResult.Failure -> result.error(
                        scanResult.error.name,
                        "Scan failed: ${scanResult.error.name}",
                        null
                    )
                }
            }
        }
    }
}






