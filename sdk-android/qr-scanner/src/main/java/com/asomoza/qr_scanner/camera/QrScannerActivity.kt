package com.asomoza.qr_scanner.camera

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.asomoza.qr_scanner.QrScanner
import com.asomoza.qr_scanner.scanner.ScanAttempt
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal class QrScannerActivity : ComponentActivity() {

    private lateinit var previewView: PreviewView
    private var attempt: ScanAttempt? = null
    private var requestingPermission = false
    private val closeSelf: () -> Unit = {
        if (!isFinishing) finish()
    }

    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private val barcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
    )

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { grant ->
            requestingPermission = false
            if (grant) {
                startCamera()
            } else {
                attempt?.permissionDenied()
                finish()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        attempt = QrScanner.currentAttempt
        if (attempt == null) {
            finish()
            return
        }
        QrScanner.closeScreen = closeSelf

        previewView = PreviewView(this)
        setContentView(previewView)
        requestPermission()
    }

    private fun requestPermission() {
        val grant = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        if (grant) {
            startCamera()
        } else {
            requestingPermission = true
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    private fun startCamera() {
        val cameraProvider = ProcessCameraProvider.getInstance(this)
        cameraProvider.addListener({
            try {
                val provider = cameraProvider.get()

                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { it.setAnalyzer(analysisExecutor, ::analyze) }

                provider.unbindAll()
                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis
                )
            } catch (_: Exception) {
                attempt?.cameraUnavailable()
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val image = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
        )

        barcodeScanner.process(image)
            .addOnSuccessListener { barcodes ->
                val raw = barcodes.firstOrNull()?.rawValue ?: return@addOnSuccessListener
                val current = attempt ?: return@addOnSuccessListener
                if (!current.isFinished) {
                    current.qrDetected(raw)
                    finish()
                }
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }
    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations && !isFinishing && !requestingPermission) {
            attempt?.cancel()
        }
    }
    override fun onDestroy() {
        if (QrScanner.closeScreen === closeSelf) {
            QrScanner.closeScreen = null
        }
        if (isFinishing) {
            attempt?.cancel()
        }
        analysisExecutor.shutdown()
        barcodeScanner.close()
        super.onDestroy()
    }
}